# Regras Específicas do NxNative (GUI, Scripts e Core Engine)

> **ATENÇÃO**: Este diretório faz parte do projeto **NativePort**. Todas as regras definidas em `../GEMINI.md` e `../.agents/rules/` aplicam-se obrigatoriamente aqui.

## Invariante Zero-Hang no Launcher
1. **Nunca quebrar o botão Jogar/Launch**: Qualquer alteração em `gui/`, `scripts/` ou `dm/` deve garantir que a inicialização de jogos permaneça não bloqueante e com fail-safe watchdog ativo.
2. **Codesign Rápido**: Nunca usar `--deep` em pacotes de jogos ao abrir.
3. **Preservar Variáveis de Ambiente**: Nunca descartar `ProcessInfo.processInfo.environment` ao abrir o executável `dmhost`.
4. **Verificação Mandatória**: Antes de finalizar qualquer alteração, compilar com `cd gui && swift build -c release` e gerar o app com `scripts/build_gui.sh`.
