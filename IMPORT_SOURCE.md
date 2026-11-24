# Importar o projeto-fonte

O workflow Android já está configurado em `.github/workflows/android.yml`. Falta apenas enviar a pasta `polestar_racing/` com todos os scripts e modelos 3D.

## Termux

1. Descarrega e extrai `Multi-AMATCH-Racing-3D-source.zip`.
2. No Termux, instala as ferramentas caso ainda não estejam instaladas: `pkg install git unzip`.
3. Dá acesso à pasta de Transferências, se necessário: `termux-setup-storage`.
4. Entra na pasta extraída e executa:

   ```bash
   bash UPLOAD_TO_GITHUB_TERMUX.sh
   ```

O script clona/atualiza este repositório, copia a pasta `polestar_racing/`, cria um commit e tenta enviar para a branch `main`. Usa a autenticação Git já configurada no Termux. Não coloques passwords ou tokens dentro do script nem os partilhes no chat.

## Depois do envio

O push da pasta `polestar_racing/` inicia o workflow **Android APK**. Abre o separador **Actions** para acompanhar a exportação. Se terminar com sucesso, transfere o artefacto `Multi-AMATCH-Racing-3D-Android-debug`.

Não apagues nem substituas `polestar_racing/cars/` ou `polestar_racing/tracks/`: contêm os modelos 3D necessários para o jogo.
