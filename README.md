# GarageGame

Vertical slice de mecânica automotiva em primeira pessoa, feita em **Godot 4.7.2** e **GDScript**.

O projeto está na pasta [`garage-game/`](garage-game/). Abra `garage-game/project.godot` no Godot e pressione **F5**. Para **F6**, abra `world/garage_test.tscn` no editor.

O protótipo inclui transporte físico de objetos, montagem/desmontagem de uma roda, cinco parafusos independentes, doze chaves métricas, caixa de ferramentas, agachamento, HUD contextual e save/load por IDs persistentes.

| Controle | Ação |
|---|---|
| WASD / mouse / Space | Andar / olhar / pular |
| Ctrl | Agachar |
| LMB mantido | Pegar e carregar |
| Soltar LMB | Soltar ou encaixar no socket próximo |
| RMB + mouse durante hold | Rotacionar o objeto |
| Scroll ↑ / ↓ com chave compatível | Apertar / afrouxar parafuso |
| Shift + scroll | Ajustar distância do objeto |
| Esc / P | Liberar mouse / pausar |
| F2 / F9 / F8 / F3 | Salvar / carregar / resetar / debug |

A roda usa cinco parafusos de **17 mm**, com aperto de **0 a 4**. Qualquer parafuso acima de zero impede sua retirada; todos em 4 tornam a roda `FASTENED`.

- [Guia rápido](garage-game/README.md)
- [Arquitetura, extensão dos componentes e inventário de arquivos](garage-game/README_DEV.md)

## Validação

Na pasta `garage-game`, execute usando o caminho do seu Godot:

```text
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script res://systems/tests/prototype_test.gd
```

São 124 verificações de mecânica, física, persistência, reset e validações negativas, sem framework externo. Para gerar capturas, execute o teste sem `--headless` e acrescente `-- --visual`.

Somente meshes primitivas e materiais nativos. Os slots de áudio estão preparados, mas vazios. Esta etapa não inclui direção, cidade, NPCs ou economia.
