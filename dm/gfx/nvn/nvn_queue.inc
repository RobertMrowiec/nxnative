#include "nvn_capture.h"
#include "nvn_hmap.h"

void *objc_autoreleasePoolPush(void);
void objc_autoreleasePoolPop(void *);

// Ready continuations of NVN queues share the renderer's one ordered Metal queue.
// An unresolved wait parks its queue, never the submitting CPU or another queue.
typedef struct nq_receipt { unsigned refs, published; uint64_t fence, present; } nq_receipt;
typedef struct nq_node {
    struct nq_node *next;
    uint8_t *bytes; size_t length, capacity;
    unsigned kind, mode, closed, waiting; volatile uint32_t *event; uint32_t value;
    uint64_t wait_fence, event_predecessor; unsigned wait_kind; const sync_t *sync_source; nq_receipt *receipt;
    uint64_t park_t0; unsigned released; volatile uint32_t *park_word;   // stats: when this head first parked, what released it (1 CPU publish, 2 GPU-fenced publish, else completed predecessor / poll), and the event word it waited on
    uint64_t evw_ticket;   // DM_NVN_EVWAIT_GPU: released as a GPU-side shared-event wait with this ticket (0 otherwise)
    // DM_NVN_SUBMERGE: signals and fence syncs kept inside one commands node instead of splitting it
    struct nq_sig { volatile uint32_t *word; unsigned mode; uint32_t value; } *sigs; unsigned nsigs, sigcap;
    struct nq_fsync { nq_receipt *receipt; const sync_t *sync; } *fsyncs; unsigned nfsyncs, fsynccap;
    tex_t texture; double period; int crop[4];
} nq_node;
typedef struct nq_owned { struct nq_owned *next; unsigned kind; uint64_t data[]; } nq_owned;
typedef struct nq_job { struct nq_job *next; nq_node *first, *last; nq_receipt *receipt; nq_owned *owned; nvn_hmap objects; uint64_t frame; } nq_job;
static void nq_job_free(nq_job *j) {
    for(nq_owned *o=j->owned,*next;o;o=next) { next=o->next; if(o->kind==CAP_K_PROG) mtl_prog_unpin((prog_t *)o->data); else if(o->kind==CAP_K_TEX) mtl_tex_unpin(((tex_t *)o->data)->serial); free(o); }
    free(j->objects.keys); free(j->objects.vals); free(j);
}
static int nq_snapshot_address(void *ctx,uint64_t *field,uint64_t len,int writable) { (void)ctx;(void)field;(void)len;(void)writable;return 1; }
// DM_NVN_FLAT_NOLOCK=1: the submit thread flattens command streams without holding g_sub_mu (the worker holds that lock for a whole buffer's encode, so every submit used to block
// behind it, ~5 ms a frame both sides on the Ocarina spawn scene). The flatten walk itself is a byte copy over game-owned memory; only these descriptor snapshots touch the Metal
// side, and they take the lock just for that touch. Default off.
static int nq_flat_nolock(void) { static int v=-1; if(v<0){ const char *e=getenv("DM_NVN_FLAT_NOLOCK"); v=e&&atoi(e)?1:0; if(v) LOG("[nvn] submit flattens outside the scheduler's Metal lock (DM_NVN_FLAT_NOLOCK)"); } return v; }
static int nq_snapshot_object(void *ctx,int kind,uint64_t *field,uint8_t *payload,uint32_t size) {
    (void)payload;(void)size; nq_job *j=ctx; if(!*field || (kind!=CAP_K_PROG && kind!=CAP_K_TEX)) return 1;
    uint64_t key[2]={*field,(unsigned)kind}; nq_owned *o=nvn_hm_get(&j->objects,key);
    if(!o) {
        size_t bytes=kind==CAP_K_PROG?sizeof(prog_t):sizeof(tex_t); o=calloc(1,sizeof *o+bytes); if(!o) die("queue descriptor allocation failed");
        o->kind=kind; o->next=j->owned; j->owned=o;
        int lk=nq_flat_nolock();   // under the old path the caller already holds g_sub_mu
        if(kind==CAP_K_PROG) { if(lk) dm_host_mutex_lock(&g_sub_mu); mtl_prog_snapshot((prog_t *)o->data,(const prog_t *)(uintptr_t)*field); if(lk) pthread_mutex_unlock(&g_sub_mu); }
        else { memcpy(o->data,(const void *)(uintptr_t)*field,bytes); if(lk) dm_host_mutex_lock(&g_sub_mu); mtl_tex_pin(((tex_t *)o->data)->serial); if(lk) pthread_mutex_unlock(&g_sub_mu); }
        nvn_hm_put(&j->objects,key,o);
    }
    *field=(uintptr_t)o->data;return 1;
}
static const cap_ops nq_snapshot_ops={nq_snapshot_address,nq_snapshot_object};
typedef struct nq_queue {
    struct nq_queue *next; uint64_t serial, physical, present; int origin;
    nq_job *first, *last; nq_receipt *tail;
} nq_queue;
static pthread_mutex_t nq_mu = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t nq_cv = PTHREAD_COND_INITIALIZER;
static pthread_once_t nq_once = PTHREAD_ONCE_INIT;
static nq_queue *nq_queues;
static int nq_test_held;   // nvn_queue_test_hold: replay takes no queued work while set (unit tests only)
// The last GPU write of each event word not yet landed: its submission's fence, and for a WRITE signal the value it leaves (exact). A wait the queued value satisfies needs no
// completion: its continuation is encoded after the writer's on the one ordered Metal queue, as the next submission of one NVN queue is, and memory the writer's completion lands
// on the CPU (reports, render-target readbacks) is that same in-flight case. An ADD's result depends on the writes landing before it, so such a wait still waits for them
// A word may carry several GPU writes in flight at once when a physical buffer holds more than one
// signal (DM_NVN_SUBMERGE): each keeps a small ring of pending writes, oldest first. A wait whose
// predicate any pending exact WRITE satisfies is released at encode: the one ordered Metal queue
// runs the consumer after that write (and after every write queued before it).
static int nq_predicate(uint32_t current,unsigned mode,uint32_t target) { return mode==0 ? current==target : (uint32_t)(current-target)<0x80000000u; }
#define NQ_EW_RING 8
typedef struct nq_event_write { struct nq_event_write *next; volatile uint32_t *word; unsigned head, count; struct { uint64_t fence; uint32_t value; int exact; } e[NQ_EW_RING]; } nq_event_write;
static nq_event_write *nq_event_writes;
static nq_event_write *nq_event_write_of(volatile uint32_t *word) { nq_event_write *w=nq_event_writes; while(w && w->word!=word) w=w->next; return w; }
static uint64_t nq_event_pending(volatile uint32_t *word) {
    nq_event_write *w=nq_event_write_of(word); uint64_t f=0;
    if(w) for(unsigned i=0;i<w->count;i++) { uint64_t x=w->e[(w->head+i)%NQ_EW_RING].fence; if(x>f) f=x; }
    return f;
}
static int nq_event_queued_match(volatile uint32_t *word,unsigned mode,uint32_t target) {
    // Only the NEWEST pending write may release a wait at encode: an older entry can carry last
    // frame's value of a wrapping counter, and releasing on it runs the consumer before this
    // frame's producer (seen as a GPU hang under CPU/GPU overlap). DM_NVN_QMATCH=0 turns the
    // release-at-encode path off entirely.
    static int on=-1;
    if(on<0) { const char *e=getenv("DM_NVN_QMATCH"); on=e?atoi(e)!=0:1; }
    if(!on) return 0;
    nq_event_write *w=nq_event_write_of(word);
    if(w && w->count) { unsigned k=(w->head+w->count-1)%NQ_EW_RING;
        if(w->e[k].exact && nq_predicate(w->e[k].value,mode,target)) return 1; }
    return 0;
}
static void nq_trace(const char *what,const void *word,uint64_t a,uint64_t b);
static void nq_event_issued(volatile uint32_t *word,uint64_t fence,unsigned mode,uint32_t value) {
    nq_event_write *w=nq_event_write_of(word);
    if(!w) { w=calloc(1,sizeof *w); if(!w) die("event ordering allocation failed"); w->word=word; w->next=nq_event_writes; nq_event_writes=w; }
    if(w->count==NQ_EW_RING) { w->head=(w->head+1)%NQ_EW_RING; w->count--; }   // oldest falls out: its fence is the lowest, pending stays correct
    unsigned k=(w->head+w->count)%NQ_EW_RING;
    w->e[k].fence=fence; w->e[k].value=value; w->e[k].exact=mode==0; w->count++;
    nq_trace(mode==0?"issue_w":"issue_add",(const void *)word,value,fence);
}

enum { NQ_COMMANDS, NQ_EVENT, NQ_SYNC, NQ_FENCE, NQ_PRESENT };
static nq_receipt *nq_new(void) { nq_receipt *r=calloc(1,sizeof *r); if(!r) die("queue receipt allocation failed"); r->refs=1; return r; }
static void nq_put(nq_receipt *r) { if(r && !--r->refs) free(r); }
static void nq_set_sync(sync_t *s,nq_receipt *r) { if(s->fenced==3) nq_put((nq_receipt *)(uintptr_t)s->fence); r->refs++; s->fence=(uintptr_t)r; s->fenced=3; }
void nvn_sync_release(sync_t *s) { pthread_mutex_lock(&nq_mu); if(s->fenced==3) nq_put((nq_receipt *)(uintptr_t)s->fence); s->fenced=0; s->fence=0; pthread_mutex_unlock(&nq_mu); }
static nq_queue *nq_get(queue_t *q) {
    nq_queue *p=nq_queues; while(p && p->serial!=q->serial) p=p->next;
    if(!p) { p=calloc(1,sizeof *p); if(!p) die("queue state allocation failed"); p->serial=q->serial; p->origin=q->origin_ll; p->next=nq_queues; nq_queues=p; }
    return p;
}
static void nq_publish(nq_receipt *r,uint64_t fence) { r->fence=fence; r->published=1; pthread_cond_broadcast(&nq_cv); }
// DM_NVN_QTRACE=<first>-<last>: append one line per scheduler step between those host frames to
// <DM_TEMP>/qtrace.log: CPU and GPU event publishes (word, value), parks and releases, commits.
static FILE *nq_trace_f; static uint64_t nq_trace_a, nq_trace_b;
static int nq_trace_init(void) {
    static int v=-1;
    if(v<0) { const char *e=getenv("DM_NVN_QTRACE"); v=0;
        if(e && sscanf(e,"%llu-%llu",(unsigned long long *)&nq_trace_a,(unsigned long long *)&nq_trace_b)==2) {
            const char *t=getenv("DM_TEMP"); char p[1024]; snprintf(p,sizeof p,"%s/qtrace.log",t?t:"/tmp");
            nq_trace_f=fopen(p,"w"); v=nq_trace_f!=NULL;
            if(v) LOG("[nvn] queue trace: frames %llu-%llu to %s (DM_NVN_QTRACE)",(unsigned long long)nq_trace_a,(unsigned long long)nq_trace_b,p);
        } }
    return v;
}
static void nq_trace(const char *what,const void *word,uint64_t a,uint64_t b) {
    if(!nq_trace_init()) return;
    uint64_t f=dm_nvn_frame_count(); if(f<nq_trace_a || f>nq_trace_b) return;
    fprintf(nq_trace_f,"%.3f\tf%llu\t%s\t%p\t%llu\t%llu\n",now_ns()/1e6,(unsigned long long)f,what,word,(unsigned long long)a,(unsigned long long)b); fflush(nq_trace_f);
}
static int nq_sync_encoded(const sync_t *s,uint64_t *fence) {
    if(s->fenced==3) { nq_receipt *r=(nq_receipt *)(uintptr_t)s->fence; if(!r->published) return 0; *fence=r->fence; return 1; }
    if(!s->fenced) return 0; *fence=s->fence; return 1;
}
void nvn_queue_gpu_progress(void) {
    pthread_mutex_lock(&nq_mu); uint64_t done=mtl_completed_fence(); nq_event_write **p=&nq_event_writes;
    while(*p) { nq_event_write *w=*p;
        while(w->count && w->e[w->head].fence<=done) { w->head=(w->head+1)%NQ_EW_RING; w->count--; }   // oldest first: fences grow with queue order
        if(!w->count) { *p=w->next; free(w); } else p=&w->next; }
    pthread_cond_broadcast(&nq_cv); pthread_mutex_unlock(&nq_mu);
}
static void nq_event_publish(volatile uint32_t *word,unsigned mode,uint32_t value,uint64_t gpu_fence) {
    pthread_mutex_lock(&nq_mu);
    if(mode==1) atomic_fetch_add_explicit((_Atomic uint32_t *)word,value,memory_order_release);
    else atomic_store_explicit((_Atomic uint32_t *)word,value,memory_order_release);
    atomic_thread_fence(memory_order_seq_cst);
    nq_trace(gpu_fence?"pub_gpu":"pub_cpu",(const void *)word,value,gpu_fence);
    // Latch waits already reached: a subsequent signal must not erase a release.
    for(nq_queue *q=nq_queues;q;q=q->next) if(q->first && q->first->first) {
        nq_node *n=q->first->first;
        if(n->kind==NQ_EVENT && n->waiting && n->event==word && (gpu_fence ? gpu_fence>=n->event_predecessor : nq_event_pending(word)<=mtl_completed_fence()) && nq_predicate(atomic_load_explicit((_Atomic uint32_t *)word,memory_order_acquire),n->mode,n->value)) { n->released=gpu_fence?2:1; n->event=NULL; n->wait_fence=gpu_fence; }
    }
    pthread_cond_broadcast(&nq_cv); pthread_mutex_unlock(&nq_mu);
}
void nvn_queue_evw_poll(void);
void nvn_event_publish(volatile uint32_t *word,unsigned mode,uint32_t value) { nq_event_publish(word,mode,value,0); nvn_queue_evw_poll(); }
void nvn_event_publish_gpu(volatile uint32_t *word,unsigned mode,uint32_t value,uint64_t fence) { nq_event_publish(word,mode,value,fence); nvn_queue_evw_poll(); }
static void nq_snapshot_sync(nq_node *n,const sync_t *s) {
    n->wait_kind=s->fenced; n->wait_fence=s->fence;
    if(s->fenced==3) { n->receipt=(nq_receipt *)(uintptr_t)s->fence; n->receipt->refs++; }
}
typedef struct { uint64_t wall, cpu, instr, cycles, sys; } nq_cost;
static nq_cost nq_cost_begin(void) {
    nq_cost c={.wall=now_ns(),.cpu=clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID),.sys=thr_sys_ns()};
    thr_counts(&c.instr,&c.cycles); return c;
}
static void nq_cost_end(nq_cost c) {
    uint64_t dw=now_ns()-c.wall, dc=clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)-c.cpu, ins, cyc; thr_counts(&ins,&cyc);
    atomic_fetch_add(&g_nvn_ns,dw); atomic_fetch_add(&g_sub_wall_ns,dw); atomic_fetch_add(&g_cum_sub_wall_ns,dw);
    atomic_fetch_add(&g_sub_cpu_ns,dc); atomic_fetch_add(&g_cum_sub_cpu_ns,dc);
    atomic_fetch_add(&g_sub_instr,ins-c.instr); atomic_fetch_add(&g_cum_sub_instr,ins-c.instr);
    atomic_fetch_add(&g_cum_sub_cyc,cyc-c.cycles); atomic_fetch_add(&g_cum_sub_sys_ns,thr_sys_ns()-c.sys);
}
// Scheduler stats (read per frame for DM_NVN_TSV): physical command commits from replay; replay-thread waits
// while a queue holds parked work (a dependency stall: an unresolved event or an unpublished sync at a head)
// against waits with no queued work at all (the game has not submitted: the frame boundary).
static _Atomic uint64_t nq_stat_commits, nq_stat_stall_ns, nq_stat_stalls, nq_stat_idle_ns;
void nvn_queue_stats(uint64_t *commits, uint64_t *stall_ns, uint64_t *stalls, uint64_t *idle_ns) {
    *commits=atomic_load(&nq_stat_commits); *stall_ns=atomic_load(&nq_stat_stall_ns);
    *stalls=atomic_load(&nq_stat_stalls); *idle_ns=atomic_load(&nq_stat_idle_ns);
}
// Park time by what ended it: a CPU event publish, a GPU-fenced publish, a completed predecessor (poll), a published sync.
static _Atomic uint64_t nq_stat_park_ns[4], nq_stat_park_n[4];
void nvn_queue_park_stats(uint64_t ns[4], uint64_t n[4]) { for(int i=0;i<4;i++) { ns[i]=atomic_load(&nq_stat_park_ns[i]); n[i]=atomic_load(&nq_stat_park_n[i]); } }
// The event words whose waits park longest (guest addresses): a small table, logged every 1800 frames.
typedef struct { volatile uint32_t *word; uint64_t ns, n; } nq_park_word;
static nq_park_word nq_park_words[64];
static void nq_park_account(nq_node *node,uint64_t now) {
    if(!node->park_t0) return;
    uint64_t d=now-node->park_t0; unsigned k=node->kind==NQ_SYNC?3:node->released==1?0:node->released==2?1:2;
    atomic_fetch_add(&nq_stat_park_ns[k],d); atomic_fetch_add(&nq_stat_park_n[k],1);
    volatile uint32_t *w=node->park_word;
    if(w) for(int i=0;i<64;i++) { if(nq_park_words[i].word==w || !nq_park_words[i].word) { nq_park_words[i].word=w; nq_park_words[i].ns+=d; nq_park_words[i].n++; break; } }
    node->park_t0=0;
}
void nvn_queue_park_report(void) {
    pthread_mutex_lock(&nq_mu);
    for(int pass=0;pass<8;pass++) { int best=-1; uint64_t bn=0;
        for(int i=0;i<64;i++) if(nq_park_words[i].word && nq_park_words[i].ns>bn) { bn=nq_park_words[i].ns; best=i; }
        if(best<0) break;
        LOG("[nvn] [qstat] event %p: %llu parks, %.1f ms total", (void *)nq_park_words[best].word, (unsigned long long)nq_park_words[best].n, nq_park_words[best].ns/1e6);
        nq_park_words[best].word=NULL; nq_park_words[best].ns=nq_park_words[best].n=0;
    }
    for(int i=0;i<64;i++) { nq_park_words[i].word=NULL; nq_park_words[i].ns=nq_park_words[i].n=0; }
    pthread_mutex_unlock(&nq_mu);
}
// DM_NVN_EVWAIT_GPU=1: a wait on a CPU-signaled event (no queued GPU write pending for the word) does not park the replay. The replay encodes a GPU-side wait on one shared
// event and keeps encoding; the game's publish (or the poll below) signals the ticket once the predicate holds. Tickets are released strictly in order, which matches the one
// ordered Metal queue the continuations share. A head stuck past 250 ms is force-signaled with a RED (a wrong draw beats a dead queue); on the console that order would hang too.
static int nq_evw_on(void) {
    static int v=-1;
    if(v<0) { const char *e=getenv("DM_NVN_EVWAIT_GPU"); v=e?atoi(e)!=0:0; if(v) LOG("[nvn] CPU-event waits encode a GPU-side wait instead of parking the replay (DM_NVN_EVWAIT_GPU)"); }
    return v;
}
void mtl_evw_wait(uint64_t ticket); void mtl_evw_signal(uint64_t ticket);   // nvn_mtl.m: one shared event on the ordered queue
typedef struct { volatile uint32_t *word; uint32_t mode, value; uint64_t ticket, t0; } nq_evw_ent;
enum { NQ_EVW_MAX=512 };
static nq_evw_ent nq_evw_q[NQ_EVW_MAX]; static uint64_t nq_evw_head, nq_evw_tail, nq_evw_ticket;   // under nq_evw_mu
static pthread_mutex_t nq_evw_mu=PTHREAD_MUTEX_INITIALIZER;
static _Atomic uint64_t nq_evw_n, nq_evw_forced;
static int nq_evw_pending(void) { return nq_evw_head!=nq_evw_tail; }   // racy read, used only to pick a timed wait
void nvn_queue_evw_poll(void) {
    if(nq_evw_head==nq_evw_tail) return;
    uint64_t sig=0;
    pthread_mutex_lock(&nq_evw_mu);
    while(nq_evw_head<nq_evw_tail) {
        nq_evw_ent *e=&nq_evw_q[nq_evw_head%NQ_EVW_MAX];
        if(nq_predicate(atomic_load_explicit((_Atomic uint32_t *)e->word,memory_order_acquire),e->mode,e->value)) { sig=e->ticket; nq_evw_head++; continue; }
        if(now_ns()-e->t0>250000000ull) { atomic_fetch_add(&nq_evw_forced,1); static int said; if(!said++) LOG("[RED] a GPU event wait sat 250 ms (word %p value %u): force-signaled (DM_NVN_EVWAIT_GPU)",(const void *)e->word,e->value); sig=e->ticket; nq_evw_head++; continue; }
        break;
    }
    if(sig) mtl_evw_signal(sig);   // under the lock: tickets must reach the shared event in order
    pthread_mutex_unlock(&nq_evw_mu);
}
void nvn_queue_evw_stats(uint64_t *n,uint64_t *forced) { *n=atomic_load(&nq_evw_n); *forced=atomic_load(&nq_evw_forced); }
static uint64_t nq_evw_add(volatile uint32_t *word,uint32_t mode,uint32_t value) {   // 0 = table full: the caller parks as before
    pthread_mutex_lock(&nq_evw_mu);
    if(nq_evw_tail-nq_evw_head>=NQ_EVW_MAX) { pthread_mutex_unlock(&nq_evw_mu); return 0; }
    uint64_t t=++nq_evw_ticket; nq_evw_q[nq_evw_tail%NQ_EVW_MAX]=(nq_evw_ent){word,mode,value,t,now_ns()}; nq_evw_tail++;
    pthread_mutex_unlock(&nq_evw_mu);
    atomic_fetch_add(&nq_evw_n,1);
    return t;
}
static int nq_merge_on(void) {
    static int v=-1;
    if(v<0) { const char *e=getenv("DM_NVN_QMERGE"); v=e?atoi(e)!=0:0; if(v) LOG("[nvn] queue merge: consecutive ready command nodes of a job share one Metal commit (DM_NVN_QMERGE)"); }
    return v;
}
// One physical command buffer per game submission: a signal no longer ends the commands node; its
// GPU write stays inside the buffer and its CPU-visible record (nq_event_issued) lands at the one
// commit, as a pending-ring entry, so release-at-encode still sees every intermediate value.
static int nq_submerge_on(void) {
    static int v=-1;
    if(v<0) { const char *e=getenv("DM_NVN_SUBMERGE"); v=e?atoi(e)!=0:1; if(v) LOG("[nvn] submission merge: one physical command buffer per game submission (DM_NVN_SUBMERGE)"); }
    return v;
}
static void *nq_worker(void *unused) {
    (void)unused; pthread_setname_np("NVN queue replay");
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE,0);
    uint64_t frame=UINT64_MAX;
    for(;;) {
        pthread_mutex_lock(&nq_mu); nq_queue *q=NULL; nq_node *n=NULL; nq_job *j=NULL;
        for(;;) {
        scan_again:;
            if(nq_test_held) { pthread_cond_wait(&nq_cv,&nq_mu); continue; }
            int mapped_event_wait=0;
            for(q=nq_queues;q;q=q->next) {
                j=q->first; if(!j) continue; n=j->first;
                if(!n) { nq_publish(j->receipt,q->physical); q->first=j->next; if(!q->first) q->last=NULL; nq_put(j->receipt);
                    pthread_mutex_unlock(&nq_mu); pthread_mutex_lock(&g_sub_mu); void *pool=objc_autoreleasePoolPush(); nq_job_free(j); objc_autoreleasePoolPop(pool); pthread_mutex_unlock(&g_sub_mu); pthread_mutex_lock(&nq_mu); goto scan_again; }
                if(n->kind==NQ_EVENT && n->event) {
                    uint64_t predecessor=nq_event_pending(n->event);
                    if(!n->waiting) n->event_predecessor=predecessor;
                    // The queued GPU write satisfies the wait: the GPU runs this continuation after it (nq_event_write). Ocarina of Time waits on about 25 events a frame; each wait
                    // for the writer's completion left the GPU idle while the host encoded the next submission, 2 ms of its 14.5 ms frame, which its dynamic resolution read as work
                    if(predecessor>mtl_completed_fence() && nq_event_queued_match(n->event,n->mode,n->value)) break;
                    if(predecessor>mtl_completed_fence() || !nq_predicate(atomic_load_explicit((_Atomic uint32_t *)n->event,memory_order_acquire),n->mode,n->value)) {
                        if(nq_evw_on() && predecessor<=mtl_completed_fence()) {   // only the CPU can satisfy this word now: encode a GPU-side wait and keep the replay moving
                            uint64_t tk=nq_evw_add(n->event,n->mode,n->value);
                            if(tk) { nq_trace("evw",(const void *)n->event,n->value,q->serial); if(n->park_t0) nq_park_account(n,now_ns()); n->released=3; n->event=NULL; n->evw_ticket=tk; break; }
                        }
                        if(!n->park_t0) { n->park_t0=now_ns(); n->park_word=n->event; nq_trace("park",(const void *)n->event,n->value,q->serial); } n->waiting=1; mapped_event_wait=1; continue; }
                }
                if(n->kind==NQ_SYNC) {
                    if(n->receipt && !n->receipt->published) { if(!n->park_t0) n->park_t0=now_ns(); continue; }
                    // Targets are immutable snapshots. One Metal queue orders an encoded producer before this continuation. A sync not yet fenced when the wait was submitted
                    // (wait_kind 0) is a snapshot of nothing to wait for, and the wait passes. Sparking! ZERO, on one NVN queue, waits on a sync before that queue's own first
                    // fence of it at its first load, which runs on the console; parked here, the fence behind the wait never published and its SyncWait stalled the game (#1808)
                }
                break;
            }
            if(q) break;
            // NVN events can also be changed by plain stores through mapped pool memory.
            // A bounded notification poll only while such a word is awaited complements API/callback wakes.
            int parked_work=0; for(nq_queue *x=nq_queues;x;x=x->next) if(x->first) { parked_work=1; break; }
            uint64_t w0=now_ns();
            if(mapped_event_wait || (nq_evw_on() && nq_evw_pending())) { struct timespec tick={0,1000000}; pthread_cond_timedwait_relative_np(&nq_cv,&nq_mu,&tick); if(nq_evw_on()) { pthread_mutex_unlock(&nq_mu); nvn_queue_evw_poll(); pthread_mutex_lock(&nq_mu); } }
            else pthread_cond_wait(&nq_cv,&nq_mu);
            uint64_t dw=now_ns()-w0;
            if(parked_work) { atomic_fetch_add(&nq_stat_stall_ns,dw); atomic_fetch_add(&nq_stat_stalls,1); }
            else atomic_fetch_add(&nq_stat_idle_ns,dw);
        }
        j->first=n->next; if(!j->first) j->last=NULL;
        if((n->kind==NQ_EVENT || n->kind==NQ_SYNC) && n->park_t0) { nq_trace("release",(const void *)n->park_word,n->released,q->serial); nq_park_account(n,now_ns()); }
        // DM_NVN_QMERGE: batch the ready command nodes that follow this one in its job into one Metal commit.
        // A SIGNAL_EVENT ends a command node (nq_flatten), so a frame becomes dozens of small physical command
        // buffers; their fences land here instead, after the one merged commit, which stays correct (a receipt may
        // publish any fence at or past its producer) and keeps the GPU fed. Collection stops at any wait.
        enum { NQ_MERGE_MAX=32 };
        nq_node *batch[NQ_MERGE_MAX]; int nbatch=0;
        if(n->kind==NQ_COMMANDS && nq_merge_on()) {
            // At most one event-signaling command node per batch, and only as its last command
            // member: a second signal in the same physical buffer can hide the first's value from
            // a cross-queue wait released at encode (the QMERGE v1 flicker). Fences ride along:
            // they publish the merged commit's fence, which is what they would have published.
            int sig = n->event != NULL;
            while(nbatch<NQ_MERGE_MAX-1 && j->first) {
                nq_node *m=j->first;
                if(m->kind==NQ_FENCE && m->receipt) { j->first=m->next; if(!j->first) j->last=NULL; batch[nbatch++]=m; continue; }
                if(m->kind==NQ_COMMANDS && !sig) { j->first=m->next; if(!j->first) j->last=NULL; batch[nbatch++]=m; if(m->event) sig=1; continue; }
                break;
            }
        }
        // Round-robin ready queues: a continually fed independent producer cannot starve another queue.
        if(q->next) { nq_queue **link=&nq_queues; while(*link!=q) link=&(*link)->next; *link=q->next; nq_queue *tail=nq_queues; while(tail->next) tail=tail->next; tail->next=q; q->next=NULL; }
        if(n->kind==NQ_SYNC || n->kind==NQ_EVENT) { uint64_t f=n->receipt?n->receipt->fence:n->wait_fence; if(f>q->physical) q->physical=f; }
        if(n->kind==NQ_FENCE) nq_publish(n->receipt,q->physical);
        pthread_mutex_unlock(&nq_mu);
        if(n->kind==NQ_EVENT && n->evw_ticket) {   // DM_NVN_EVWAIT_GPU: later commits on the ordered queue run only once the ticket is signaled
            dm_host_mutex_lock(&g_sub_mu); mtl_evw_wait(n->evw_ticket); pthread_mutex_unlock(&g_sub_mu);
            nvn_queue_evw_poll();   // the publish may have landed between the decision and the encode
        }
        uint64_t fence=0, present=0;
        if(n->kind==NQ_COMMANDS || n->kind==NQ_PRESENT) {
            dm_host_mutex_lock(&g_sub_mu); void *pool=objc_autoreleasePoolPush();
            dm_host_work++; mtl_prepare(); dm_host_work--;
            gfx_enter(); nq_cost cost=nq_cost_begin();
            if(frame!=j->frame) { frame=j->frame; mtl_set_frame(frame); }
            mtl_queue_activate(q->serial); mtl_set_queue_origin_lower_left(q->origin);
            if(n->kind==NQ_COMMANDS) {
                uint64_t handles[NQ_MERGE_MAX]; int nh=0;
                handles[nh++]=(uintptr_t)n->bytes;
                for(int i=0;i<nbatch;i++) if(batch[i]->kind==NQ_COMMANDS) handles[nh++]=(uintptr_t)batch[i]->bytes;
                nvn_cap_submit(nh,handles);
                mtl_sub_begin(); nvn_ft_poll(); mtl_sub_index(handles,nh);
                for(int i=0;i<nh;i++) { mtl_exec_rest(handles+i+1,nh-i-1); mtl_exec((const uint8_t *)(uintptr_t)handles[i]); }
                fence=mtl_sub_commit();
                if(fence) atomic_fetch_add(&nq_stat_commits,1);
                nq_trace("commit",NULL,fence,(uint64_t)nh);
            } else {
                nvn_cap_present(&n->texture,n->crop);
                present=mtl_present(&n->texture,n->period,n->crop); mtl_tex_unpin(n->texture.serial);
            }
            nq_cost_end(cost); gfx_leave(); objc_autoreleasePoolPop(pool); pthread_mutex_unlock(&g_sub_mu);
        }
        pthread_mutex_lock(&nq_mu); if(n->kind==NQ_PRESENT) { q->present=present; j->receipt->present=present; } if(fence) { q->physical=fence; if(n->event) nq_event_issued(n->event,fence,n->mode,n->value); }
        if(fence) for(unsigned i=0;i<n->nsigs;i++) nq_event_issued(n->sigs[i].word,fence,n->sigs[i].mode,n->sigs[i].value);
        for(unsigned i=0;i<n->nfsyncs;i++) { nq_publish(n->fsyncs[i].receipt,q->physical); nq_put(n->fsyncs[i].receipt); }
        free(n->sigs); free(n->fsyncs);
        for(int i=0;i<nbatch;i++) { nq_node *m=batch[i];
            if(fence && m->event) nq_event_issued(m->event,fence,m->mode,m->value);
            if(fence) for(unsigned k=0;k<m->nsigs;k++) nq_event_issued(m->sigs[k].word,fence,m->sigs[k].mode,m->sigs[k].value);
            for(unsigned k=0;k<m->nfsyncs;k++) { nq_publish(m->fsyncs[k].receipt,q->physical); nq_put(m->fsyncs[k].receipt); }
            free(m->sigs); free(m->fsyncs);
            if(m->kind==NQ_FENCE) nq_publish(m->receipt,q->physical);
            if(m->receipt) nq_put(m->receipt); free(m->bytes); free(m); }
        if(n->receipt) nq_put(n->receipt); free(n->bytes); free(n); pthread_cond_broadcast(&nq_cv); pthread_mutex_unlock(&nq_mu);
    }
    return NULL;
}
static void nq_start(void) { pthread_t t; if(pthread_create(&t,NULL,nq_worker,NULL)) die("NVN queue worker failed"); pthread_detach(t); }
static nq_node *nq_append(nq_job *j,unsigned kind) { nq_node *n=calloc(1,sizeof *n); if(!n) die("queue continuation allocation failed"); n->kind=kind; if(j->last) j->last->next=n; else j->first=n; j->last=n; return n; }
static void nq_bytes(nq_node *n,const void *bytes,size_t length) { if(n->length+length>n->capacity) { n->capacity=(n->length+length+4095)&~(size_t)4095; n->bytes=realloc(n->bytes,n->capacity); if(!n->bytes) die("queue commands allocation failed"); } memcpy(n->bytes+n->length,bytes,length); n->length+=length; }
static void nq_end(nq_job *j) { if(j->last && j->last->kind==NQ_COMMANDS && !j->last->closed) { op_hdr end={OP_END,8}; nq_bytes(j->last,&end,8); j->last->closed=1; } }
static void nq_flatten(nq_job *j,const uint8_t *p,unsigned depth) {
    if(depth>64) die("NVN command call nesting exceeds64");
    for(;;) {
        op_hdr h; memcpy(&h,p,8); if(h.size<8 || h.size&7) die("invalid NVN command size"); const uint8_t *a=p+8;
        if(h.op==OP_END) return;
        if(h.op==OP_JUMP) { memcpy(&p,a,8); continue; }
        if(h.op==OP_CALL) { const uint8_t *called; memcpy(&called,a,8); nq_flatten(j,called,depth+1); p+=h.size; continue; }
        if(h.op==OP_WAIT_EVENT || h.op==OP_WAIT_SYNC || (h.op==OP_FENCE_SYNC && !nq_submerge_on())) {
            nq_end(j); nq_node *n=nq_append(j,h.op==OP_WAIT_EVENT?NQ_EVENT:h.op==OP_WAIT_SYNC?NQ_SYNC:NQ_FENCE);
            if(h.op==OP_WAIT_EVENT) { memcpy(&n->event,a,8); memcpy(&n->mode,a+8,4); memcpy(&n->value,a+12,4); }
            else { memcpy(&n->sync_source,a,8); if(h.op==OP_FENCE_SYNC) n->receipt=nq_new(); }
        } else if(h.op==OP_FENCE_SYNC) {   // submerge: the receipt publishes at this node's one commit
            nq_node *n=j->last; if(!n || n->kind!=NQ_COMMANDS || n->closed) n=nq_append(j,NQ_COMMANDS);
            if(n->nfsyncs==n->fsynccap) { n->fsynccap=n->fsynccap?n->fsynccap*2:4; n->fsyncs=realloc(n->fsyncs,n->fsynccap*sizeof *n->fsyncs); if(!n->fsyncs) die("fence sync list allocation failed"); }
            n->fsyncs[n->nfsyncs].receipt=nq_new(); memcpy(&n->fsyncs[n->nfsyncs].sync,a,8); n->nfsyncs++;
        } else {
            nq_node *n=j->last; if(!n || n->kind!=NQ_COMMANDS || n->closed) n=nq_append(j,NQ_COMMANDS);
            size_t offset=n->length; nq_bytes(n,p,h.size);
            if(!cap_rec_fields(h.op,n->bytes+offset+8,h.size,&nq_snapshot_ops,j)) die("queue snapshot: unknown command %u",h.op);
            if(h.op==OP_SIGNAL_EVENT) {
                if(nq_submerge_on()) {
                    if(n->nsigs==n->sigcap) { n->sigcap=n->sigcap?n->sigcap*2:4; n->sigs=realloc(n->sigs,n->sigcap*sizeof *n->sigs); if(!n->sigs) die("signal list allocation failed"); }
                    memcpy(&n->sigs[n->nsigs].word,a,8); memcpy(&n->sigs[n->nsigs].mode,a+8,4); memcpy(&n->sigs[n->nsigs].value,a+12,4); n->nsigs++;
                } else { memcpy(&n->event,a,8); memcpy(&n->mode,a+8,4); memcpy(&n->value,a+12,4); nq_end(j); nq_append(j,NQ_FENCE)->receipt=nq_new(); }
            }
        }
        p+=h.size;
    }
}
static void nq_enqueue(nq_queue *q,nq_job *j) { if(q->last) q->last->next=j; else q->first=j; q->last=j; nq_put(q->tail); q->tail=j->receipt; q->tail->refs++; pthread_cond_broadcast(&nq_cv); }
static _Atomic uint64_t nq_stat_submu_ns, nq_stat_submu_n;   // game-thread time blocked on g_sub_mu in submit
static _Atomic uint64_t nq_stat_flat_ns;                     // game-thread time flattening and copying command streams
void nvn_queue_submu_stats(uint64_t *ns, uint64_t *n) { *ns=atomic_load(&nq_stat_submu_ns); *n=atomic_load(&nq_stat_submu_n); }
uint64_t nvn_queue_flat_ns(void) { return atomic_load(&nq_stat_flat_ns); }
void nvn_queue_submit(queue_t *q,int count,const uint64_t *handles) {
    pthread_once(&nq_once,nq_start); nq_job *j=calloc(1,sizeof *j); if(!j) die("queue job allocation failed"); j->receipt=nq_new();
    j->objects.klen=16; j->frame=dm_nvn_frame_count();
    // No scheduler lock while copying descriptors or resolving shader libraries.
    uint64_t lk0=now_ns();
    if(nq_flat_nolock()) {   // hold g_sub_mu only for mtl_prepare; the flatten walk runs beside the worker's encode (descriptor snapshots re-take the lock briefly)
        dm_host_mutex_lock(&g_sub_mu);
        { uint64_t d=now_ns()-lk0; if(d>10000) { atomic_fetch_add(&nq_stat_submu_ns,d); atomic_fetch_add(&nq_stat_submu_n,1); } }
        dm_host_work++; mtl_prepare(); dm_host_work--;
        pthread_mutex_unlock(&g_sub_mu);
        void *pool=objc_autoreleasePoolPush(); nq_cost cost=nq_cost_begin();
        uint64_t fl0=now_ns();
        for(int i=0;i<count;i++) nq_flatten(j,(const uint8_t *)(uintptr_t)handles[i],0); nq_end(j);
        atomic_fetch_add(&nq_stat_flat_ns,now_ns()-fl0);
        nq_cost_end(cost); objc_autoreleasePoolPop(pool);
    } else {
    dm_host_mutex_lock(&g_sub_mu);
    { uint64_t d=now_ns()-lk0; if(d>10000) { atomic_fetch_add(&nq_stat_submu_ns,d); atomic_fetch_add(&nq_stat_submu_n,1); } }
    void *pool=objc_autoreleasePoolPush(); dm_host_work++; mtl_prepare(); dm_host_work--; nq_cost cost=nq_cost_begin();
    uint64_t fl0=now_ns();
    for(int i=0;i<count;i++) nq_flatten(j,(const uint8_t *)(uintptr_t)handles[i],0); nq_end(j);
    atomic_fetch_add(&nq_stat_flat_ns,now_ns()-fl0);
    nq_cost_end(cost); objc_autoreleasePoolPop(pool); pthread_mutex_unlock(&g_sub_mu);
    }
    int waits=0; for(nq_node *node=j->first;node;node=node->next) waits|=node->kind==NQ_EVENT || node->kind==NQ_SYNC;
    nvn_cap_queue(q->serial,waits);
    pthread_mutex_lock(&nq_mu);
    for(nq_node *node=j->first;node;node=node->next) {
        if(node->sync_source) {
            if(node->kind==NQ_FENCE) nq_set_sync((sync_t *)node->sync_source,node->receipt); else nq_snapshot_sync(node,node->sync_source);
            node->sync_source=NULL;
        }
        for(unsigned i=0;i<node->nfsyncs;i++) nq_set_sync((sync_t *)node->fsyncs[i].sync,node->fsyncs[i].receipt);
    }
    nq_enqueue(nq_get(q),j); pthread_mutex_unlock(&nq_mu);
    nq_trace("submit",NULL,q->serial,(uint64_t)waits);
}
// The window retains this logical receipt until it reacquires or finalizes that image.
// Only replay turns it into a physical display ticket; present never waits on the guest thread.
uint64_t nvn_queue_present(queue_t *q,const tex_t *t,double period,const int crop[4]) {
    nvn_cap_queue(q->serial,0);
    pthread_once(&nq_once,nq_start); nq_job *j=calloc(1,sizeof *j); if(!j) die("queue present allocation failed");
    j->receipt=nq_new(); j->frame=dm_nvn_frame_count(); nq_node *n=nq_append(j,NQ_PRESENT);
    n->texture=*t; mtl_tex_pin(t->serial); n->period=period; if(crop) memcpy(n->crop,crop,sizeof n->crop);
    pthread_mutex_lock(&nq_mu); j->receipt->refs++; uint64_t ticket=(uintptr_t)j->receipt;
    nq_enqueue(nq_get(q),j); pthread_mutex_unlock(&nq_mu); return ticket;
}
void nvn_queue_test_hold(int on) { pthread_mutex_lock(&nq_mu); nq_test_held=on; pthread_cond_broadcast(&nq_cv); pthread_mutex_unlock(&nq_mu); }
void nvn_queue_present_release(uint64_t ticket) {
    if(!ticket) return; pthread_mutex_lock(&nq_mu); nq_put((nq_receipt *)(uintptr_t)ticket); pthread_mutex_unlock(&nq_mu);
}
void nvn_queue_present_wait(uint64_t ticket) {
    if(!ticket) return; nq_receipt *r=(nq_receipt *)(uintptr_t)ticket;
    pthread_mutex_lock(&nq_mu); while(!r->published) pthread_cond_wait(&nq_cv,&nq_mu); uint64_t physical=r->present; pthread_mutex_unlock(&nq_mu);
    if(physical) mtl_present_wait(physical);
}
void nvn_queue_fence(queue_t *q,sync_t *s) {
    pthread_mutex_lock(&nq_mu); nq_queue *p=nq_get(q);
    if(p->tail) nq_set_sync(s,p->tail); else { if(s->fenced==3) nq_put((nq_receipt *)(uintptr_t)s->fence); s->fenced=1; s->fence=p->physical; }
    pthread_mutex_unlock(&nq_mu);
}
int nvn_sync_wait(const sync_t *s,uint64_t timeout) {
    uint64_t start=now_ns(),fence=0; pthread_mutex_lock(&nq_mu);
    while(!nq_sync_encoded(s,&fence)) {
        uint64_t elapsed=now_ns()-start; if(timeout!=UINT64_MAX && elapsed>=timeout) { pthread_mutex_unlock(&nq_mu); return 0; }
        if(timeout==UINT64_MAX) pthread_cond_wait(&nq_cv,&nq_mu);
        else { uint64_t left=timeout-elapsed; struct timespec ts={(time_t)(left/1000000000ull),(long)(left%1000000000ull)}; pthread_cond_timedwait_relative_np(&nq_cv,&nq_mu,&ts); }
    }
    pthread_mutex_unlock(&nq_mu); uint64_t elapsed=now_ns()-start;
    return mtl_wait(fence,timeout==UINT64_MAX?timeout:elapsed>=timeout?0:timeout-elapsed);
}
void nvn_queue_wait_sync(queue_t *q,const sync_t *s) {
    nvn_cap_queue(q->serial,1);
    pthread_once(&nq_once,nq_start); nq_job *j=calloc(1,sizeof *j); if(!j) die("queue wait allocation failed"); j->receipt=nq_new();
    pthread_mutex_lock(&nq_mu); nq_snapshot_sync(nq_append(j,NQ_SYNC),s); nq_enqueue(nq_get(q),j); pthread_mutex_unlock(&nq_mu);
}
void nvn_queue_finish(queue_t *q) { sync_t s={0}; nvn_queue_fence(q,&s); nvn_sync_wait(&s,UINT64_MAX); nvn_sync_release(&s);
    pthread_mutex_lock(&nq_mu); uint64_t present=nq_get(q)->present; pthread_mutex_unlock(&nq_mu);
    if(present) mtl_present_wait(present);
}
void nvn_queue_forget(queue_t *q) { nvn_queue_finish(q); pthread_mutex_lock(&nq_mu); nq_queue **p=&nq_queues; while(*p && (*p)->serial!=q->serial) p=&(*p)->next; if(*p) { nq_queue *old=*p; *p=old->next; nq_put(old->tail); free(old); } pthread_mutex_unlock(&nq_mu); }
