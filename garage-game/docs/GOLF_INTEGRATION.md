# Golf Mk4 — integração de desenvolvimento

Atualizado em 11/09/2026. Referência visual local, não comercial; não distribuir
o asset do Golf em builds de produção.

## Cena atual e preservação

F5 abre `world/garage_golf_test.tscn`, que instancia
`vehicles/car_golf_integrated.tscn`. A integração herda a cena anterior; não
reconstrói a carroceria e não substitui o Golf por geometria procedural.
O conjunto é montado em `_ready()`; use a árvore **Remote** durante a execução
para inspecionar as quatro rodas, sockets, helpers e colisões finais.

Backup completo anterior às mudanças:
`C:/GarageGame-backups/golf-before-integration-20260911-204102`.
Inclui o projeto, arquivos locais de referência e configuração de ignore.
`vehicles/car_golf_reference_test.tscn`, `world/garage_test.tscn` e os arquivos
antigos de carroceria continuam preservados. Nenhum push foi feito nesta etapa.

O arquivo de trabalho da referência é `blender/source/golf_reference_test.blend`.
O FBX original e o ZIP fornecido não foram alterados.

## CAR SCALE / GROUND

Medições de vértices usados por faces, não de bounds contaminados por vértices
soltos. Fonte: `blender/reports/golf_reference_integration.json`; a reimportação
dos sete GLBs é validada por `golf_reference_export_validation.json`.

| Medida | Resultado |
|---|---:|
| Bounds originais FBX, X/Y/Z | 0,020187 / 0,041426 / 0,017197 m |
| Escala uniforme adicional aplicada | 100,178174139 |
| Comprimento final | 4,150000 m |
| Largura da carroceria, sem espelhos | 1,747119 m |
| Altura do teto, a partir do chão | 1,408285 m |
| Entre-eixos | 2,506690 m |
| Largura total, incluindo espelhos | 2,022259 m |
| Altura máxima, incluindo antena | 1,722738 m |
| Centro dos quatro pneus acima do chão | 0,307435 m |
| Raio geométrico dos pneus | 0,307435 m |
| Largura máxima do conjunto de roda | 0,219281 m |
| Ground no Godot | Y = 0 m |
| Vão livre da geometria inferior do carro | 0,136155 m |

Os transforms originais variam por objeto: carroceria tem escala local 1 e
world scale 0,01; pneus têm escala local 1,65088 e world scale 0,016509. A lista
completa está em `source_transforms` do relatório. Os transforms foram aplicados
ao exportar; raízes de carro, rodas e rigid bodies trabalham com escala 1.

O comprimento já era métrico no teste anterior. O deslocamento visual de
0,485 m, os cavaletes e o alinhamento aos sockets antigos eram a causa da postura
flutuante. Eles foram removidos da variante integrada. O teto da referência R32
mede 1,408 m; não foi deformado nem levantado para forçar o valor nominal 1,44 m.
Comprimento, largura e entre-eixos aproximam os alvos sem escala não uniforme.

Blender: **X largura, Y comprimento, Z altura**, frente em -Y.
Godot: **X largura, Y altura, Z comprimento**, frente em +Z.
A conversão é `(x, y, z) Blender -> (x, z, -y) Godot`.
Esquerda do veículo é +X, e direita é -X. Não se confundem com esquerda/direita
de uma pessoa olhando o carro de frente.

O carro fica em `(1, 0, -1)` na garagem. Centros abaixo são locais ao carro:

| Roda | Centro Godot X/Y/Z, em metros | ID persistente | Situação |
|---|---|---|---|
| FL | +0,742542 / 0,307435 / +1,195712 | `front_left_wheel` | Remoção, física, reinstalação, reaperto e reset testados |
| FR | -0,742542 / 0,307435 / +1,195712 | `front_right_wheel` | Remoção, física, reinstalação, reaperto e reset testados |
| RL | +0,734919 / 0,307435 / -1,310977 | `rear_left_wheel` | Remoção, física, reinstalação, reaperto e reset testados |
| RR | -0,734919 / 0,307435 / -1,310977 | `rear_right_wheel` | Remoção, física, reinstalação, reaperto e reset testados |

Os quatro contatos medidos no Godot estão a menos de 0,001 mm do plano Y=0.
A simetria bilateral é verificada com tolerância de 2 mm; sockets e origens de
instalação são verificados com tolerância de 1 mm.

## WHEELS / FASTENERS

Cada roda é um `AutomotivePart` independente (a implementação de VehiclePart
existente neste projeto), com três meshes importadas: aro, banda e lateral do
pneu. Os cilindros procedurais antigos não ficam sobrepostos ao Golf.

Os nós são `socket_wheel_fl/fr/rl/rr`; os IDs persistentes dos sockets são
`front_left_wheel_socket`, `front_right_wheel_socket`, `rear_left_wheel_socket`
e `rear_right_wheel_socket`. Cada canto tem um tipo de encaixe exclusivo.

São 20 parafusos, cinco por roda, todos exigindo chave 17 mm, em círculo de
100 mm de diâmetro. IDs: `<wheel_id>_bolt_1` até `<wheel_id>_bolt_5`. O padrão
numérico da FL foi preservado para compatibilidade com saves. Cada tightness
varia independentemente de 0 a 4 e é salvo individualmente.

Qualquer aperto acima de zero impede remoção e mostra
“Afrouxe todos os 5 parafusos”. Fora do socket a roda usa seu `RigidBody3D`
normal, massa 12 kg, collider cilíndrico e gravidade. Instalada, fica congelada
no transform do socket. Reinstalação produz `PLACED`, nunca aperta os parafusos
automaticamente. Os cinco apertos completos são necessários para `FASTENED`.

Disco e pinça FL usam as meshes reais separadas do Golf, removidas da exportação
da carroceria para não duplicar. Cubo e amortecedor existentes foram reposicionados
e redimensionados uniformemente. Os freios dos outros três cantos continuam
visuais importados; não foram inventados três novos sistemas desmontáveis de
suspensão/freios. As quatro **rodas**, porém, são totalmente independentes.

## HOOD

Mesh móvel: `Volkswagen_Golf_mk_IV_R32:SM_Hood_0000_002_SM_Hood_0000_4996fa8`.
O chunk `SM_Hood ... 6b03548` contém cowl/limpadores e permanece imóvel.
O capô procedural não aparece na variante integrada.

Pivô central das dobradiças: `(0, 0,916, 0,868230)` em coordenadas Godot locais.
Gira -65° no eixo X em 0,65 s, com interpolação suave. Fechado, retorna exatamente
ao transform original da superfície importada. A colisão acompanha a dobradiça
com quatro faixas finas, não com uma caixa grande acima do motor.

Mire o capô sem item equipado: `[LMB] Abrir` / `[LMB] Fechar`.
Se estiver com ferramenta, G solta primeiro; LMB não troca o objeto da mão.
O estado aberto/fechado é salvo por `golf_hood` e F8 fecha o capô.

## ENGINE BAY / COLLIDERS

`EngineBayReference` contém os sete marcadores solicitados. Envelope útil local:
X -0,60..0,60, Y 0,22..0,80, Z 1,07..1,83 m. A altura disponível real varia com
a superfície do capô, amostrada por raios no Blender. As caixas de roda invadem
as extremidades baixas: componentes inferiores ficam perto do centro.

| Componente | Centro local Godot X/Y/Z | Integração |
|---|---|---|
| Bateria | -0,40 / 0,60 / 1,63 | Part, mount, terminais e conexões preservados |
| Radiador | 0 / 0,49 / 1,75 | Atrás da dianteira, antes do motor |
| Caixa do filtro | +0,38 / 0,72 / 1,22 | Part e fixações preservados |
| Alternador | +0,30 / 0,49 / 1,56 | Part, correia e conexão existentes preservados |
| Motor de partida | -0,29 / 0,43 / 1,47 | Part e conexão preservados |
| Bloco transversal | +0,035 / 0,48 / 1,30 | Representação volumétrica temporária |
| Tampa de válvulas | +0,035 / 0,71 / 1,30 | Representação volumétrica temporária |
| Transmissão lateral | -0,32 / 0,35 / 1,25 | Representação volumétrica temporária |
| Reservatório | +0,47 / 0,61 / 1,60 | Representação volumétrica temporária |

As cinco peças de serviço antigas tiveram visual, collider e origem ajustados
em conjunto; nenhuma escala não uniforme foi aplicada. Seus scripts mecânicos
e elétricos continuam ativos. O layout sugere motor dianteiro transversal/FWD,
mas não implementa direção, transmissão final ou tubulação detalhada.

Limitação explícita: bloco, tampa, transmissão e reservatório ainda são volumes
simples proporcionais; não são peças detalhadas do R32. Esta etapa corrige o
espaço e o gameplay, mas o cofre ainda não tem acabamento de um motor real.

Colisões estáticas simples: assoalho fino, cabine, firewall, travessa frontal
e trilhos laterais. Não há cavaletes nem caixa de suporte elevando o visual.
O carro é estático neste protótipo de manutenção: não cai quando as rodas são
retiradas. A física de apoio/direção do chassi não faz parte desta etapa.

F3 desenha origens de partes (branco), origens visuais (verde), sockets (ciano),
colliders (laranja) e fasteners (rosa), com legenda e rótulos de rodas.
O jogador começa em `(3,8, 0,05, 2,8)`, fora do carro, câmera adulta de 1,62 m.

## INTERACTION

- LMB uma vez (`grab_item`): pegar ferramenta ou peça. Soltar LMB não solta o item.
- G (`drop_item`): largar; encaixa se houver socket compatível destacado e alcançável.
- Scroll para cima: apertar. Scroll para baixo: afrouxar.
- Scroll em parafuso exige ferramenta equipada, tipo/tamanho corretos e alvo válido.
- Chave 15 mm não altera bolt 17 mm; HUD informa “Requer chave 17 mm”.
- Com ferramenta equipada, LMB não pega parafusos nem troca o objeto da mão.
- Ctrl: agachar; WASD: andar; RMB + mouse: girar peça; R + scroll: distância da peça.
- F2/F9: salvar/carregar; F8: reset; F3: debug; Esc: liberar mouse.

A chave mede aproximadamente 26 cm; não há redução da física para caber na
câmera. `Tool.hold_position = (0,25, -0,21, -0,50)`, `hold_rotation = (55, 0, 25)`
em graus e `hold_scale = 1` são configuráveis. A escala de hold só afeta o visual.

Fluxo completo: pegar chave 17 com um clique → afrouxar cinco bolts → G para
largar chave → LMB na roda → transportar sem segurar botão → G para largar ou
encaixar → pegar chave novamente → reapertar cinco bolts.

## SAVE / RESET

Schema 3 mantido. Cada roda salva ID, estado, transform, socket, condição e
fixações individuais. Saves antigos recebem apenas os conjuntos FR/RL/RR
inteiramente ausentes e o estado inicial fechado do capô. Registros existentes
não são sobrescritos pela migração. Duplicatas, conjuntos parcialmente ausentes
ou falta de peças antigas continuam sendo rejeitados antes de alterar a cena.

F8 reinstala e aperta as quatro rodas/20 bolts, devolve ferramentas, restaura
peças e sistemas do motor, fecha capô, reposiciona carro e devolve o player ao spawn.
Os testes usam arquivo de save separado e não substituem o save do jogador.

## TESTS / SCREENSHOTS

Executados com Godot 4.7.2 e Blender 5.2.1:

- Reimportação dos sete GLBs: **31 verificações, zero falhas**.
- Regressão anterior `prototype_test.gd`: **100 verificações, zero falhas**.
- Regressão anterior na variante Golf: **111 verificações, zero falhas**.
- Integração Golf: **312 verificações, zero falhas**, incluindo raycasts reais,
  quatro rodas soltas/transportadas/reinstaladas, reaperto dos 20 bolts, ferramenta
  errada, capô interpolado por clique, bounds, dez fixações do cofre alcançáveis,
  F3, save/load parcial, migração e reset.
- Pacote de exportação de conferência: **134 entradas, zero caminhos Golf ou
  external_reference**. Inicialização headless do pacote sem erros.

Os testes movimentam o player por trajetos de fixture, mas o transporte da roda
até o socket usa o spring/física real, e o encaixe usa G. Não substituem a
avaliação humana de ergonomia. Warnings de saves deliberadamente inválidos são
esperados; não são falhas de parser ou runtime.

Comandos, na raiz `garage-game`:

```text
Godot --headless --path . --editor --import --quit
Godot --headless --path . --fixed-fps 60 --script res://systems/tests/prototype_test.gd
Godot --headless --path . --fixed-fps 60 --script res://systems/tests/prototype_test.gd -- --golf-reference
Godot --headless --path . --fixed-fps 60 --script res://systems/tests/golf_integration_test.gd
Godot --path . --fixed-fps 60 --script res://systems/tests/golf_integration_test.gd -- --visual
blender --background --python blender/scripts/validate_golf_integration.py
```

Capturas reais do Godot em `blender/previews/golf_reference/`:
`car_side.png`, `car_front_3q.png`, `car_rear_3q.png`, `hood_closed.png`,
`hood_open.png`, `engine_bay.png`, `wheel_removed_fl.png`,
`all_wheels_installed.png`. Há também `tool_held_17mm.png`, mostrando a chave
equipada e o HUD em primeira pessoa. O runner gera os originais em `.godot/golf_validation/`.

Ainda requer teste manual: conforto do hold, mira em parafusos pequenos,
transporte junto de paredes/player, percepção de peso/jitter, legibilidade em
outras resoluções e aprovação visual do cofre temporário. As vistas capturadas
foram inspecionadas; não equivalem a uma auditoria de todas as possíveis poses
de objetos soltos ou de cada triângulo do modelo.

## FILES

Criados nesta integração:

- `vehicles/car_golf_integrated.tscn`, `golf_reference_integration.gd`,
  `golf_hood.gd`, `golf_hood_target.gd`, `golf_alignment_debug.gd`.
- `systems/save/snapshot_migration.gd`, `systems/tests/golf_integration_test.gd`.
- `blender/scripts/integrate_golf_reference.py`, `inspect_golf_integration.py`,
  `validate_golf_integration.py` e relatórios correspondentes.
- GLBs independentes das rodas FR/RL/RR, disco FL e pinça FL; nove screenshots.
- Este documento e UIDs de scripts gerados pelo Godot.

Modificados nesta integração:

- `project.godot`, `world/garage_golf_test.tscn`, `export_presets.cfg`, `.gitignore`.
- `vehicles/car_visual_bridge.gd`, `vehicles/fasteners/fastener.gd`.
- `systems/interaction_controller.gd`, `part_carrier.gd`, `grabbable.gd`, `snap_socket.gd`.
- `parts/automotive_part.gd`, `player/first_person_player.gd`.
- `tools/tool.gd`, `tool_slot.gd`, `wrench.tscn`.
- `systems/save/save_system.gd`, `systems/tests/prototype_test.gd`, `mechanics_checks.gd`.
- `blender/source/golf_reference_test.blend`, GLBs de carroceria e roda FL.
- `README.md`, `README_DEV.md`, `docs/GOLF_REFERENCE_TEST.md`.

## Problemas reais encontrados no asset / publicação

O FBX contém chunks separados por material com **32.780 vértices órfãos** de
outros grupos, que corrompiam bounds por objeto. Foram removidos somente vértices
não usados por faces; os **81.855 triângulos** foram preservados. Os dois pneus
agrupados foram separados geometricamente nos quatro cantos. `SM_Hub` significa
aro/raios nessa fonte, não o cubo mecânico. O chunk do capô também inclui cowl
estático separado; somente a superfície pintada segue a dobradiça.

O preset `Commercial Windows (Reference Safe)` usa exclusões explícitas de todos
os assets, relatórios e cenas Golf, além da feature `reference_safe`, que seleciona
a cena anterior na exportação. Isso não muda a cena local de desenvolvimento.
A substituição por feature é suportada pelo
[Godot ProjectSettings](https://docs.godotengine.org/en/latest/tutorials/export/feature_tags.html).
O pacote de auditoria é local; nenhum jogo foi publicado. A configuração de
ignore mantém os assets de referência fora do Git.
