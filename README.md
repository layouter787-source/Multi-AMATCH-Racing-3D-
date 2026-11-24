# Multi-AMATCH Racing 3D

Jogo arcade de corridas 3D para Android, baseado em Godot 4.3 (GL Compatibility).

## Estado real do repositório

- Identidade do jogo e repositório: **Multi-AMATCH Racing 3D**.
- Workflow de Android instalado em `.github/workflows/android.yml`.
- O projeto-fonte Godot completo ainda precisa de ser importado para a pasta `polestar_racing/`. O pacote-fonte preparado inclui scripts, modelos 3D, pistas, preset Android e documentação.
- Ainda não existe APK compilado nem teste multiplayer concluído.

## O jogo-fonte preparado

- Cinco pistas: Vale Verde, Deserto Rubi, Costa Azul, Montanha Nevada e Cidade Noturna.
- Vários carros 3D, corrida solo com IA, garagem e controlos tácteis.
- Multijogador LAN/hotspot ENet, configurado para até 15 participantes por sala, incluindo o anfitrião.
- Descoberta local por UDP broadcast e entrada por IP.
- Portas: UDP 7777 (corrida) e UDP 7778 (descoberta LAN).

## Compilação Android

Depois de a pasta `polestar_racing/` ser adicionada à raiz, cada push que alterar essa pasta inicia o workflow. O resultado é um **APK Debug** publicado como artefacto do GitHub Actions.

O limite de 15 está configurado no código, mas ainda necessita de testes em aparelhos reais. A meta de 64.000 jogadores globais não está implementada: exigiria backend e servidores dedicados.
