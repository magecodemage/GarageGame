# Código publicado e referência local

O Git contém o código, as cenas autorais Godot, os geradores Blender e o macaco
original. **Não contém o modelo Golf, suas texturas, arquivos derivados,
relatórios geométricos ou capturas que o mostram.** O asset continua marcado
`REFERENCE ONLY / DO NOT SHIP / NON-COMMERCIAL ASSET`. Esta publicação não concede
licença sobre o modelo de terceiros e não fornece download automático dele.

## O que acontece ao abrir

Abra `project.godot` no Godot 4.7.2 e pressione F5. A entrada
`world/project_entry.tscn` verifica os arquivos locais necessários:

- Com os arquivos presentes, abre **a mesma** `world/garage_golf_test.tscn`, com
  Golf, suspensão e macaco atuais. Não recria a garagem nem altera suas poses.
- Num clone sem a referência, mostra quais arquivos estão ausentes e aponta
  para este documento. **Não carrega o carro procedural nem outro substituto.**

F6 na cena Golf requer os mesmos arquivos. A ausência do modelo não é um teste
aprovado da mecânica: o aviso apenas permite abrir honestamente o código público.

## Preparar a referência autorizada

Use uma cópia do modelo à qual você já tenha acesso autorizado. O pipeline atual
espera o FBX `FINAL_MODEL_IV_R32.fbx` e suas texturas, sem mudar nomes internos,
nesta localização relativa à pasta `garage-game`:

```text
external_reference/golf_mk4_reference/source/FINAL_MODEL_IV_R32/
    FINAL_MODEL_IV_R32.fbx
    [texturas do mesmo asset]
```

Não use um Golf diferente como entrada esperando os mesmos sockets: estes
geradores identificam objetos e ilhas geométricas do arquivo específico usado
no desenvolvimento. Preserve o ZIP/FBX original. Os caminhos acima e todas as
saídas derivadas permanecem ignorados pelo Git.

Alternativamente, numa segunda máquina autorizada, copie do seu ambiente de
trabalho os arquivos derivados listados abaixo para os mesmos caminhos. Isso
não exige reconstruir o projeto ou modificar a cena.

## Gerar os arquivos locais

Foi usado Blender 5.2.1. Execute a partir de `garage-game`, ajustando somente o
caminho do executável. Faça backup das saídas locais que tenham edição manual:
os geradores substituem seus próprios `.blend`, `.glb` e relatórios de trabalho,
mas não substituem o FBX original.

```powershell
$blenderExe = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
& $blenderExe --background --python blender/scripts/integrate_golf_reference.py
& $blenderExe --background --python blender/scripts/separate_golf_panels.py
& $blenderExe --background --python blender/scripts/build_golf_suspension.py
```

Execute na ordem indicada e só prossiga quando cada comando terminar sem erro.
Não execute `build_car.py` para preparar o Golf: esse gerador pertence ao
protótipo antigo preservado. O gerador de integração já faz a normalização
uniforme do FBX e produz o `.blend` de entrada dos dois passos seguintes; não é
necessário executar o importador histórico separadamente.

A entrada atual precisa destes arquivos gerados:

```text
blender/exports/golf_reference_panels.glb
blender/exports/golf_reference_wheel_fl.glb
blender/exports/golf_reference_wheel_fr.glb
blender/exports/golf_reference_wheel_rl.glb
blender/exports/golf_reference_wheel_rr.glb
blender/exports/golf_suspension_parts.glb
blender/reports/golf_reference_panels.json
vehicles/golf_suspension_manifest.json
```

O macaco original já acompanha o repositório em
`blender/source/floor_jack.blend` e `blender/exports/floor_jack.glb`. Se precisar
regenerá-lo, use `build_floor_jack.py`; ele não abre nem modifica o Golf.
Depois deixe o Godot importar os recursos e execute F5. Os geradores de assets
não substituem a validação de gameplay documentada na entrega da etapa.

## Publicação e exportação

Os `.tscn` publicados descrevem a integração, mas carregam os visuais de
referência somente em execução. Os GLBs, BLENDs, imagens, manifest e relatórios
Golf continuam locais. Não use `git add -f` para contornar essas exclusões.
EXE/PCK e saves locais também não devem entrar no commit.

O preset existente `jogo` é **somente local** e pode conter a referência:
seu nome e configurações de exportação foram preservados. Não publique sua
saída como build distribuível.

`Commercial Windows (Reference Safe)` é uma opção **explícita e separada**:
usa a feature `reference_safe` para exportar a cena anterior preservada
`world/garage_test.tscn`, com exclusões dos derivados Golf. Não representa esta
versão da suspensão/macaco e não é fallback do F5. Alterar um preset não prova
o conteúdo de um pacote: antes de distribuir um executável, audite o pacote
gerado. Nenhuma exportação é necessária apenas para publicar o código no Git.
