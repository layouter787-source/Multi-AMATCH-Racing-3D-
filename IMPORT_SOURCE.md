# Importar o projeto-fonte

O workflow Android já está no repositório. Para o primeiro APK, a pasta **polestar_racing/** com todos os ficheiros e modelos 3D tem de estar na raiz deste repositório.

1. Descarrega e extrai o ficheiro `Multi-AMATCH-Racing-3D-source.zip` preparado nesta conversa.
2. Copia a pasta `polestar_racing` para a raiz do clone local deste repositório. Mantém também `.github/workflows/android.yml`.
3. Faz commit e push para a branch `main`.

Depois do push, abre o separador **Actions**, escolhe **Android APK** e acompanha a compilação. O artefacto `Multi-AMATCH-Racing-3D-Android-debug` contém o APK, caso a exportação termine com sucesso.

Não apagues nem substituas a pasta `polestar_racing/cars/` ou `polestar_racing/tracks/`: elas contêm os modelos 3D necessários para o jogo.
