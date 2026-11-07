import SwiftUI
import AppKit

public struct SystemUpdatesCard: View {
    @ObservedObject public var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.9.9"
    }
    
    private var currentCommit: String {
        if let commit = viewModel.updateInfo?.localCommit, !commit.isEmpty {
            return commit
        }
        return UpdateCheckerService.shared.getLocalCommit(nxnativePath: viewModel.nxnativePath)
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // MARK: - Current Version & Status Header
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(NXTheme.primaryGradient)
                                .frame(width: 44, height: 44)
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("NxNative Launcher")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(NXTheme.textPrimary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("v\(appVersion) · \(currentCommit)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(NXTheme.primary.opacity(0.55))
                                .clipShape(Capsule())
                            }
                            
                            Text("GitLab: rennan-group2/nxnative_Launcher · Upstream: seedds/nxnative")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(NXTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Status Badge
                        if viewModel.isCheckingUpdate {
                            StatusBadge(isPositive: true, text: "Verificando...")
                        } else if viewModel.isApplyingUpdate || viewModel.isSyncingUpstream {
                            StatusBadge(isPositive: true, text: "Atualizando...")
                        } else if let info = viewModel.updateInfo, info.hasUpdate {
                            StatusBadge(isPositive: true, text: "Nova Versão Disponível")
                        } else {
                            StatusBadge(isPositive: true, text: "Versão Atualizada")
                        }
                    }
                    
                    Divider().opacity(0.2)
                    
                    // State Banner & Action Row
                    if viewModel.isCheckingUpdate {
                        HStack(spacing: 12) {
                            ProgressView().controlSize(.small)
                            Text("Consultando repositório remoto no GitLab para novos commits e releases...")
                                .font(.system(size: 12))
                                .foregroundColor(NXTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    } else if viewModel.updateCompletedReadyToRelaunch {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Atualização Concluída com Sucesso!")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(viewModel.updateSuccessBanner ?? "O aplicativo foi recompilado e está pronto para reiniciar.")
                                    .font(.system(size: 11))
                                    .foregroundColor(NXTheme.textSecondary)
                            }
                            Spacer()
                            Button("Reiniciar Agora") {
                                SoundEffectService.shared.play(.click)
                                viewModel.relaunchUpdatedLauncher()
                            }
                            .buttonStyle(NXPrimaryButtonStyle())
                        }
                        .padding(12)
                        .nxGlassCard(cornerRadius: 12, tint: Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.25))
                    } else if let err = viewModel.updateErrorBanner {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Aviso de Atualização")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text(err)
                                    .font(.system(size: 11))
                                    .foregroundColor(NXTheme.textSecondary)
                            }
                            Spacer()
                            Button("Tentar Novamente") {
                                SoundEffectService.shared.play(.click)
                                viewModel.checkForUpdates()
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                        }
                        .padding(12)
                        .nxGlassCard(cornerRadius: 12, tint: Color.orange.opacity(0.25))
                    } else if let info = viewModel.updateInfo, info.hasUpdate {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 22))
                                .foregroundColor(NXTheme.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Nova Atualização Encontrada!")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("[\(info.localCommit)] → [\(info.remoteCommit)] · \(info.commitMessages.count) novos commits disponíveis")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(NXTheme.textSecondary)
                            }
                            Spacer()
                            Button("Atualizar para Nova Versão") {
                                SoundEffectService.shared.play(.click)
                                viewModel.applyUpdate(autoRelaunch: true)
                            }
                            .buttonStyle(NXPrimaryButtonStyle())
                        }
                        .padding(12)
                        .nxGlassCard(cornerRadius: 12, tint: NXTheme.primary.opacity(0.25))
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                            Text("Você está utilizando a versão mais recente com todas as otimizações do motor.")
                                .font(.system(size: 12))
                                .foregroundColor(NXTheme.textSecondary)
                            Spacer()
                        }
                    }
                    
                    // Action Buttons Bar
                    HStack(spacing: 10) {
                        Button(action: {
                            SoundEffectService.shared.play(.click)
                            viewModel.checkForUpdates()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Verificar Atualizações")
                            }
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        .disabled(viewModel.isCheckingUpdate || viewModel.isApplyingUpdate || viewModel.isSyncingUpstream)
                        
                        if let info = viewModel.updateInfo, info.hasUpdate {
                            Button(action: {
                                SoundEffectService.shared.play(.click)
                                viewModel.applyUpdate(autoRelaunch: true)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Atualizar Agora")
                                }
                            }
                            .buttonStyle(NXPrimaryButtonStyle())
                            .disabled(viewModel.isApplyingUpdate)
                        }
                        
                        if viewModel.isDeveloperMode {
                            Button(action: {
                                SoundEffectService.shared.play(.click)
                                viewModel.syncUpstreamEngine()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.merge")
                                    Text("Sincronizar Upstream")
                                }
                            }
                            .buttonStyle(NXSecondaryButtonStyle())
                            .disabled(viewModel.isSyncingUpstream || viewModel.isApplyingUpdate)
                            .help("Sincroniza commits do repositório upstream seedds/nxnative")
                        }
                        
                        Button(action: {
                            if let url = URL(string: "https://gitlab.com/rennan-group2/nxnative_Launcher/-/issues") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "ladybug.fill")
                                    .foregroundColor(Color.orange)
                                Text("Issues")
                            }
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        .help("Reportar bugs, incompatibilidades ou sugerir melhorias no GitLab")

                        Button(action: {
                            if let url = URL(string: "https://gitlab.com/rennan-group2/nxnative_Launcher/-/merge_requests") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.merge")
                                    .foregroundColor(Color.cyan)
                                Text("Pull Requests")
                            }
                        }
                        .buttonStyle(NXSecondaryButtonStyle())
                        .help("Enviar Pull Requests / Merge Requests no GitLab")
                        
                        Spacer()
                    }
                    
                    // Live Install Logs console if applying update
                    if viewModel.isApplyingUpdate || viewModel.isSyncingUpstream || !viewModel.updateInstallLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Log de Atualização e Compilação")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(NXTheme.textSecondary)
                                Spacer()
                            }
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(Array(viewModel.updateInstallLogs.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundColor(line.contains("error") || line.contains("Error") ? .red : NXTheme.textSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                            }
                            .frame(height: 120)
                            .background(Color.black.opacity(0.45))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                        }
                    }
                }
                .padding(6)
            }
            
            // MARK: - What's New & Fixes (Changelog)
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("O que há de novo & Correções nesta Versão", systemImage: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(NXTheme.textPrimary)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // Highlight 1: Zelda Ocarina of Time
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("🗡️")
                                Text("The Legend of Zelda: Ocarina of Time (Switch 2 · 0400486024DEC000)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                changeItem("Vídeos e Cutscenes a 60 FPS: Desativa a rede neural NDVE (14 dispatches/frame que causavam queda para 20 fps) e aciona o reprodutor nativo 1080p sem perda de qualidade visual.")
                                changeItem("Pacing de Tempo a 60 FPS: Patch de frame_step no controlador interno de taxa de quadros, mantendo o jogo rodando a 1.0x da velocidade normal sem aceleração.")
                                changeItem("Upscaler MetalFX Spatial: Substitui o upscaler de 6 passes de compute do jogo pelo MetalFX nativo do macOS Tahoe (Metal 4), reduzindo o uso de GPU e mantendo taxa acima de 60 fps.")
                                changeItem("Gerenciamento de Memória para Macs 16 GB: Render targets com compressão Metal lossy (rt_lossy), descarte imediato de páginas de texturas enviadas (DM_TEX_RELEASE=2) e supressão de texturas retiradas (pool_skip_retired).")
                                changeItem("Overlays de Resolução Automáticos: Empacota automaticamente presets de resolução (docked, handheld e modo leve potato) em Contents/Resources/romfs_overlay.")
                            }
                            .padding(.leading, 8)
                        }
                        .padding(10)
                        .nxGlassCard(cornerRadius: 10, tint: Color.blue.opacity(0.18))
                        
                        // Highlight 2: Launcher & Motor
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("🚀")
                                Text("NxNative Launcher & Sistema")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                changeItem("Aba de Atualizações Integrada: Visualização direta de novos commits, novidades e instalação automatizada com reinicialização em 1 clique.")
                                changeItem("Injeção Inteligente de Ambiente: Configurações de MetalFX e render scale salvas sem sobrescrever parâmetros específicos de títulos complexos.")
                                changeItem("Isolamento Estrito por Jogo: Otimizações específicas de Ocarina of Time são ativadas exclusivamente pelo Title ID (0400486024DEC000), garantindo 100% de compatibilidade para todos os demais jogos da biblioteca.")
                            }
                            .padding(.leading, 8)
                        }
                        .padding(10)
                        .nxGlassCard(cornerRadius: 10, tint: Color.purple.opacity(0.18))
                        
                        // Commits list from git if available
                        if let info = viewModel.updateInfo, !info.commitMessages.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Commits no Repositório Remoto:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(NXTheme.textSecondary)
                                ForEach(info.commitMessages.prefix(10), id: \.self) { msg in
                                    Text("• \(msg)")
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundColor(NXTheme.textMuted)
                                }
                            }
                            .padding(8)
                            .nxGlassCard(cornerRadius: 8)
                        }
                    }
                }
                .padding(6)
            }
            
            // MARK: - Game Porting Instructions
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Como aplicar as melhorias nos seus jogos", systemImage: "info.circle.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(NXTheme.textPrimary)
                    
                    HStack(alignment: .top, spacing: 14) {
                        // For New Ports
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color(red: 0.13, green: 0.77, blue: 0.37))
                                Text("Para quem vai portar pela primeira vez:")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("100% automático. Basta ir na aba Portar Jogo, selecionar o NSP/NUP do Zelda Ocarina of Time e iniciar. O Launcher aplica todos os patches, compila o motor dmhost com MetalFX e gera o romfs_overlay sem nenhuma ação manual necessária.")
                                .font(.system(size: 11))
                                .foregroundColor(NXTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .nxGlassCard(cornerRadius: 10)
                        
                        // For Existing Ports
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .foregroundColor(NXTheme.secondary)
                                Text("Para quem já portou o jogo anteriormente:")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Como o bundle (.app) é independente, para receber o novo executável dmhost, os vídeos a 60 FPS e o overlay de resolução, clique em 'Portar novamente' na pasta do jogo. Como o cache de extração e shaders é preservado, o re-build dura cerca de 1 a 2 minutos.")
                                .font(.system(size: 11))
                                .foregroundColor(NXTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .nxGlassCard(cornerRadius: 10)
                    }
                }
                .padding(6)
            }
        }
    }
    
    @ViewBuilder
    private func changeItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundColor(NXTheme.secondary)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(NXTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
