# GarageGame — vertical slice de mecânica

Abra `project.godot` no **Godot 4.7.2** e pressione **F5**.
O desenvolvimento local abre o Golf. Um clone sem os recursos mostra as
[instruções de preparação](docs/GIT_REFERENCE_SETUP.md), sem carro substituto.
Para **F6**, abra `world/garage_golf_test.tscn` com os recursos locais presentes.
Asset somente de referência, não publicado no Git. Etapa atual:
[suspensão e macaco](docs/GOLF_JACK.md).

- **WASD**: andar; **mouse**: olhar; **Space**: pular; **Ctrl**: agachar.
- **LMB uma vez**: pegar e manter a peça/ferramenta. **G**: soltar ou encaixar no socket destacado.
- **RMB + mouse**: rotacionar o objeto sem girar a câmera.
- **R + scroll**: ajustar a distância da peça.
- Com uma chave na mão, **scroll ↑/↓** sobre um parafuso: apertar/afrouxar.
- **Macaco**: LMB pega; G encaixa no ponto próximo; scroll ↑/↓ mirando nele levanta/baixa.
- **Esc**: liberar mouse; clique para continuar. **P**: pausar. A ferramenta continua equipada.
- **F2**: salvar; **F9**: carregar; **F8**: resetar; **F3**: debug.

Leve a roda ao encaixe do carro e pressione G quando ele destacar.
As quatro rodas usam **chave 17 mm**, cinco parafusos independentes em cada roda.
A roda só fica `FASTENED` quando todos chegam a 4/4.
Para removê-la, todos devem voltar a zero e o canto deve estar apoiado pelo macaco.

A caixa atual contém chaves de 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 e 21 mm.
Para guardá-las, leve a chave por cima da borda até o slot destacado e solte.
LMB sem item equipado sobre a caixa/tampa ou capô abre ou fecha.

Arquitetura, formatos, limites, inventário de arquivos e testes:
[README_DEV.md](README_DEV.md).
