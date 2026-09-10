# GarageGame — vertical slice de mecânica

Abra `project.godot` no **Godot 4.7.2** e pressione **F5**.
Para **F6**, abra `world/garage_test.tscn`.

- **WASD**: andar; **mouse**: olhar; **Space**: pular; **Ctrl**: agachar.
- **Segurar LMB**: pegar e carregar. **Soltar LMB**: largar ou encaixar automaticamente se houver um socket válido próximo.
- **RMB + mouse**, mantendo LMB: rotacionar o objeto sem girar a câmera.
- **Shift + scroll**: ajustar a distância do objeto.
- Com uma chave na mão, **scroll ↑/↓** sobre um parafuso: apertar/afrouxar.
- **Esc**: liberar mouse e objeto; clique para continuar. **P**: pausar.
- **F2**: salvar; **F9**: carregar; **F8**: resetar; **F3**: debug.

Leve a roda ao encaixe do carro e solte LMB quando ele destacar.
Pegue a **chave 17 mm** na caixa sobre a bancada e aperte os cinco parafusos.
A roda só fica `FASTENED` quando todos chegam a 4/4.
Para removê-la, todos devem voltar a zero.

A caixa contém chaves de 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17 e 19 mm.
Para guardá-las, leve a chave por cima da borda até o slot destacado e solte.
LMB sobre a caixa/tampa abre ou fecha.

Arquitetura, formatos, limites, inventário de arquivos e testes:
[README_DEV.md](README_DEV.md).
