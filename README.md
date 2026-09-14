# GarageGame

Vertical slice de mecânica automotiva em primeira pessoa, feita em **Godot 4.7.2** e **GDScript**.

O projeto está na pasta [`garage-game/`](garage-game/). Abra `garage-game/project.godot` no Godot e pressione **F5**. A entrada abre a garagem atual quando os recursos locais estão disponíveis; um clone sem o modelo mostra as instruções de preparação, sem substituir o carro.

O protótipo atual inclui quatro rodas independentes, 20 parafusos de roda, 46 peças de suspensão, ferramentas métricas, macaco de chão, HUD contextual e save/load por IDs persistentes. O Golf é referência visual local de desenvolvimento e **não está incluído no Git**. Veja [preparação dos recursos locais](garage-game/docs/GIT_REFERENCE_SETUP.md).

| Controle | Ação |
|---|---|
| WASD / mouse / Space | Andar / olhar / pular |
| Ctrl | Agachar |
| LMB uma vez | Pegar e manter na mão |
| G | Soltar ou encaixar no socket próximo |
| RMB + mouse durante hold | Rotacionar o objeto |
| Scroll ↑ / ↓ com chave compatível | Apertar / afrouxar parafuso |
| R + scroll | Ajustar alcance do objeto/ferramenta |
| Scroll ↑ / ↓ mirando macaco posicionado | Levantar / baixar |
| Esc / P | Liberar mouse / pausar |
| F2 / F9 / F8 / F3 | Salvar / carregar / resetar / debug |

Cada roda usa cinco parafusos de **17 mm**, com aperto de **0 a 4**. A retirada exige o canto apoiado pelo macaco e todos os parafusos soltos; encaixar não aperta os parafusos automaticamente.

- [Guia rápido](garage-game/README.md)
- [Arquitetura, extensão dos componentes e inventário de arquivos](garage-game/README_DEV.md)

## Validação

Na pasta `garage-game`, execute usando o caminho do seu Godot:

```text
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script res://systems/tests/prototype_test.gd
```

O runner acima cobre o protótipo legado preservado. A validação da suspensão/macaco atual e suas limitações são registradas em [GOLF_JACK.md](garage-game/docs/GOLF_JACK.md); não é necessário repetir toda a suíte antiga para testar um canto.

Os modelos próprios do macaco e seus fontes Blender acompanham o código. Assets Golf, derivados, capturas com o modelo, saves, caches e executáveis locais não são publicados. Esta etapa não inclui direção, cidade, NPCs ou economia.
