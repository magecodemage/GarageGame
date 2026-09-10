# README_DEV — GarageGame / vertical slice

## Escopo e execução

Godot **4.7.2**, GDScript tipado, Jolt Physics e Forward+ / Direct3D 12 do
projeto original. Garagem, bancada, carro e roda foram reaproveitados.
Os meshes são primitivas nativas; não há addons, assets externos ou shaders
personalizados. Não há cidade, NPCs, economia ou direção.

**F5** executa a cena principal configurada; **F6** executa
`world/garage_test.tscn` quando aberta no editor.

Cena atual: um carro estático, uma roda física funcional, um socket, cinco
parafusos independentes, uma caixa ancorada na bancada e doze chaves métricas.
As outras rodas do carro continuam sendo meshes de referência sem mecânica.

## Controles / InputMap

| Ação | Entrada | Comportamento |
|---|---|---|
| move_forward/backward/left/right | W / S / A / D | Movimento com aceleração/desaceleração limitada |
| jump | Space | Pulo discreto, em pé e no chão |
| crouch | Ctrl mantido | Reduz cápsula, câmera e velocidade |
| primary_interact | LMB mantido | Pega no pressionamento, carrega enquanto mantido |
| primary_interact released | Soltar LMB | Solta sempre; instala/guarda se houver candidato válido |
| secondary_interact | RMB + mouse, durante hold | Rotaciona o item, consumindo movimento da câmera |
| tighten / loosen | Scroll ↑ / ↓ | Um nível por evento sobre um parafuso |
| adjust_hold_distance | Shift + scroll | Ajusta hold_distance dentro dos limites |
| release_mouse | Esc | Libera mouse, encerra hold; clique para recapturar |
| pause | P | Pausa/retoma, liberando o objeto ao pausar |
| save_game | F2 | Salva manualmente |
| load_game | F9 | Restaura o save |
| reset_test_scene | F8 | Retorna ao snapshot inicial, sem apagar o save |
| debug_toggle | F3 | Mostra/oculta dados do alvo |

F2 evita o conflito de F5 com execução no editor. E/Q antigos foram removidos.
O clique que recaptura o mouse é consumido: solte e pressione novamente para
pegar. Perder o foco também encerra a interação.

O scroll usa ações do InputMap, mas é processado **por evento** e enfileirado
até o tick físico. Isso preserva múltiplos ticks no mesmo frame. Shift tem
prioridade sobre aperto quando há um item na mão. Não há toggle de hold.

## Arquitetura e dependências

- `FirstPersonPlayer`: movimento, câmera e postura. Encaminha entrada ao
  controlador antes de girar a câmera; não conhece rodas, bolts ou chaves.
- `InteractionController`: RayCast, bordas de LMB, fila de scroll e contexto.
- `InteractionTarget`: adaptador local registrado no collider. Delega
  `interaction_context(held)`, `interaction_primary()` e
  `interaction_scroll(held, direction)` ao objeto. O collider da tampa usa
  o mesmo adaptador da caixa. Meta é só referência em memória, nunca ID de save.
- `Grabbable`: RigidBody3D compartilhado por `AutomotivePart` e `Tool`;
  mantém física, hold, soltura, áudio e ciclo de placement.
- `PartCarrier`: força/damping/alcance configuráveis, orientação de hold,
  ShapeCast de segurança e escolha do socket próximo.
- `SnapSocket`: placement e preview comuns; `PartSocket` e `ToolSlot`
  implementam suas regras de compatibilidade.
- `PartSocket`: agrega somente os Fasteners do seu `fastener_root`.
- `Fastener`: estado individual, valida ToolSpec, emite sinais e fornece HUD.
- `Toolbox`: instancia e identifica ferramentas/slots a partir de cenas e
  tamanhos exportados; controla acessibilidade e tampa.
- `SaveSystem`: I/O e mensagens. Registry, Snapshot, Codec e Validator
  separam identificação, aplicação, representação e validação.
- `GarageSession`: atalhos de desenvolvimento e pausa.
- `InteractionHUD`: escuta contextos; não aplica regras mecânicas.

A base Grabbable não importa subclasses ou sockets. A referência
`placement_socket: Node3D` usa o protocolo `is_accessible/remove_item` e
`installation_point` do SnapSocket. Isso evita dependência circular entre
a base física e os sockets. O Player só conhece o controlador.

Use referências exportadas para compor componentes no editor. As buscas por
grupo são limitadas a serviços de seleção/registro, sem buscar objetos por nome
globalmente. IDs de persistência não dependem da hierarquia.

## Física do hold

O objeto permanece na sua hierarquia de mundo enquanto é carregado. Não é
congelado nem parentado à câmera. `_integrate_forces` aplica uma mola amortecida
com compensação de gravidade e limite de força. A posição alvo é suavizada;
a orientação alvo usa quaternions e velocidade angular limitada.

Parâmetros no PartCarrier:

- `hold_distance`: 1,35 m; distância mínima 0,85 m, ajuste até 2,3 m.
- `max_hold_distance`: 3,2 m; além desse alcance o hold é encerrado.
- `hold_strength`: 90; `hold_damping`: 18.
- `max_hold_force`: 900 N; `target_speed`: 4,5 m/s.
- Massa acima de 8 kg reduz a resposta da mola; o limite de força continua
  valendo para todos os itens.

O corpo mantém colisões com mundo, carro e outros objetos. Só o contato com o
jogador é ignorado durante hold. Ao soltar, velocidades são limitadas a
2,5 m/s e 4 rad/s. Se jogador e item ainda estiverem sobrepostos, o contato
entre eles retorna após separação; o item já está livre nesse intervalo.

O ShapeCast usa uma esfera conservadora `carry_radius`. Ela pode impedir
aproximar uma ferramenta da borda da caixa: levante-a por cima da borda antes
de guardar. Mantenha esse raio coerente com o volume do mesh/colisão.

Head bob é opcional, muito sutil e desativado por padrão.
Quando ativado, não atua durante hold, para preservar precisão.
Crouch testa espaço acima antes de expandir a cápsula.

## Estados e regras de montagem

`AutomotivePart.State`:

| Estado | Significado |
|---|---|
| FREE | Corpo solto |
| HELD | LMB mantido, transporte físico |
| PLACED | Encaixado, nenhum aperto |
| PARTIALLY_FASTENED | Algum aperto, ainda incompleto |
| FASTENED | Todos os fasteners exigidos no máximo |

A propriedade `installed` indica placement, não fixação.
`current_socket`, `fastened` e `fastening_ratio` são derivados do vínculo/
estado. `get_fastening_ratio()` soma tightness e divide pela soma dos máximos:
[4, 4, 2, 0, 4] resulta em **0,7**.

Qualquer fastener com tightness > 0 bloqueia remoção. Em zero, a roda pode ser
retirada por LMB. Um socket sem requisito de fasteners pode fixar imediatamente.
Sockets com requisitos de fasteners não atingem FASTENED sem seus fasteners.

**Esclarecimento de aceitação:** uma roda recém-encaixada começa com os cinco
bolts em zero e pode ser removida. O teste de bloqueio é feito depois de apertar
pelo menos um bolt. Encaixar não aperta automaticamente.

Nesta etapa, PLACED/PARTIALLY_FASTENED também ficam congelados no marcador para
estabilidade. Aperto incorreto é permitido e fica representado no estado/ratio;
vibração, queda e falhas por mau aperto serão implementadas posteriormente.

Os bolts são representações cativas no cubo: em zero ficam totalmente soltos,
mas não viram objetos soltos no chão. Só ficam visíveis/interativos com a peça
encaixada. Há cinco volumes de seleção separados; o raycast encontra os bolts
na frente da face da roda.

## Criar uma peça

1. Crie uma cena com RigidBody3D usando `parts/automotive_part.gd`.
2. Acrescente mesh(es), CollisionShape3D e, opcionalmente, InteractionAudio.
3. Configure `part_id` único, `display_name`, `part_type`,
   `compatible_socket_types`, `mass` e `carry_radius`.
4. Defina `required_fasteners`; zero para peças que não exigem parafusos.
5. Configure `condition`, `wear` e `part_metadata` quando necessário.
   Metadados salvos devem ser compatíveis com JSON.
6. Use layer VehiclePart e máscara World + VehiclePart + Player + Tool + Vehicle.
7. `installation_position` e `installation_rotation_degrees` são offsets
   locais do item após o offset do socket.

O exemplo `WheelPrototype` tem ID `front_left_wheel`, tipo `wheel`, aceita
`wheel_hub`, massa de 12 kg e cinco fasteners necessários.

Para trocar primitivas por modelos futuros, substitua os nós visuais e ajuste
os volumes físicos/raio. Preserve o corpo, os componentes e referências;
a lógica não depende do nome do mesh.

## Criar um socket

1. Use `PartSocket` em um Area3D.
2. Configure `socket_id` único e `socket_type`.
3. Preencha `compatible_part_types`.
4. Crie Marker3D e MeshInstance3D para o preview e atribua as referências
   `installation_point` e `preview`.
5. O preview deve ter StandardMaterial3D como material_override.
6. Ajuste `snap_distance`, `snap_position` e `snap_rotation` (graus).
7. Se exigir parafusos, ative `requires_fasteners`, crie Fasteners sob um
   Node3D e atribua `fastener_root`.

A quantidade de bolts deve corresponder a required_fasteners da peça.
O socket aceita por tipo/família, não por nome de cena. Occupied é derivado de
installed_item; PartSocket também expõe installed_part.

O candidato é escolhido pela distância **real da peça**, mesmo sem mirar o
socket. Uma consulta bloqueia snap através do mundo/chassi. A roda usa alcance
de 0,68 m; slots de ferramentas usam 0,30 m. Apenas um candidato destaca por vez.
Ao soltar, o socket revalida as regras antes do snap. Após placement, a área
deixa de interceptar o raycast para permitir selecionar peça/bolts.

## Criar um fastener e definir tamanho

Duplique `vehicles/fasteners/wheel_bolt.tscn`, configure `fastener_id` e
`position_index` únicos e posicione na face externa da peça.
Crie/atribua um `FastenerSpec` com:

- `required_tool_type`, por exemplo `wrench`;
- `required_tool_size`, por exemplo 10, 13 ou 17 mm;
- `max_tightness`, quatro no exemplo.

Atribua bolt_mesh e áudio opcional. Cada instância tem tightness, installed e
locked próprios. Use `set_tightness()` para atualizar durante gameplay:
o método limita valores, atualiza visual e emite sinais. Não altere tightness
diretamente em sistemas novos.

Sinais: fastener_changed, fastener_fully_tightened e
fastener_fully_loosened. AutomotivePart fornece part_installed, part_removed e
state_changed. Tool fornece tool_picked_up/tool_dropped. Não há event bus global.

## Criar uma ferramenta / caixa

Duplique `tools/wrench.tscn`, configure tool_id único e atribua ToolSpec.
No Resource, defina tool_type, tool_size, usable e mass_kg. O Tool aplica massa
ao RigidBody3D e exibe o tamanho via Label3D.
Visuals agrupa os meshes para o pequeno movimento de uso da chave.

Toolbox exporta tool_scene, slot_scene e tool_sizes. A instância atual cria:
6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17 e 19 mm.
Cada slot valida ID **e** tamanho da ferramenta, e tem ID persistente próprio.
Para múltiplas caixas no futuro, use IDs de ferramentas distintos entre elas;
o validador acusa duplicação.

A caixa é um corpo estático ancorado à bancada. Sua tampa possui colisão e
encaminha interação à caixa. LMB abre/fecha, sem animação elaborada.
Não há transporte da caixa inteira nesta etapa.

## Collision layers

| Layer | Bit / valor | Uso |
|---|---:|---|
| 1 World | 1 | Garagem, bancada, caixa |
| 2 VehiclePart | 2 | Peças |
| 3 Socket | 4 | Alvos de placement |
| 4 Player | 8 | Cápsula do jogador |
| 5 Tool | 16 | Ferramentas |
| 6 Vehicle | 32 | Carro estático e suportes |
| 7 Fastener | 64 | Seleção de parafusos |

Máscaras: player/ShapeCast = 51; peças/ferramentas = 59;
InteractionRay = 119; teste de bloqueio de snap = 33.
Áreas de fasteners não geram resposta física. Ferramenta carregada é exceção
do raycast, mas continua um corpo físico. Paredes bloqueiam a seleção.

## Save/load, reset e validação

`SaveSystem.save_game()` grava `user://garage_slice_v1.json`.
`load_game()` lê, valida integralmente e só então altera a cena.
Não há carregamento automático ao iniciar. O arquivo temporário é gravado e
renomeado após flush; um save anterior pode ser substituído.

Schema version 1 registra:

- posição/rotação do player, pitch da câmera e agachamento;
- ID/pose de cada item, socket por ID, installed/stored;
- condição, desgaste e metadados de peças;
- ID, tightness, installed e locked de cada fastener;
- ID e estado de abertura das caixas.

IDs de referência: front_left_wheel, front_left_wheel_socket,
front_left_wheel_bolt_1 … 5, wrench_17mm, metric_toolbox_17mm_slot.
Nenhum NodePath é identidade persistida.

Objetos carregados são salvos como livres; input/velocidades não são salvos.
Load encerra o hold, solta vínculos, restaura poses, reconecta sockets, restaura
bolts e recalcula estados. Não restaura LMB como pressionado.
A aplicação espera os mesmos objetos/IDs da cena; não instancia tipos arbitrários
nem migra versões de schema nesta etapa.

Validações incluem IDs vazios/duplicados, ferramenta sem tamanho válido, socket
sem tipo/marcador, requisitos de fasteners, referências incompatíveis, aperto
fora dos limites, poses inválidas e saves incompletos. Erros de leitura/validação
produzem feedback sem alterar parcialmente a garagem.

`reset_test_scene()` reaplica um snapshot inicial em memória. Não recarrega
scripts nem apaga o arquivo de save: player, roda, bolts, caixa e ferramentas
voltam ao início.

## Áudio

InteractionAudio é um AudioStreamPlayer3D com slots exportados:
pickup_sound, drop_sound, snap_sound, tighten_sound, loosen_sound e impact_sound.
Os slots estão vazios. A lógica já dispara os eventos, com limite de frequência
para impactos. Nenhum som externo foi adicionado.
Ao usar a chave, há rotação visual curta, progresso no HUD e mudança do bolt.

## Testes

Sem frameworks ou dependências externas. Na pasta do projeto:

```text
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script res://systems/tests/prototype_test.gd
```

O runner executa movimento/crouch, fluxo A–H, persistência/reset I–J, validações
negativas e atalhos. Usa física real e entrada simulada; algumas aproximações
do player são controladas pelo teste para posicionamento repetível.
Retorna 1 se falhar; o resumo também fica em `.godot/slice_test_result.json`.

Para verificar renderização e salvar capturas:

```text
Godot --path . --script res://systems/tests/prototype_test.gd -- --visual
```

As capturas ficam em `.godot/slice_*.png`. Os testes usam outro save,
`user://garage_slice_validation.json`, removido ao terminar.
Warnings de save inválido/ID duplicado são esperados nos testes negativos.
Nenhum ERROR de parser/runtime é esperado.

Testar manualmente: conforto de mouse/sensibilidade, precisão com sua roda do
mouse, manipulação junto de paredes/caixa, crouch e eventuais particularidades
do mouse capturado na janela embutida do editor. Estados e regras têm cobertura
automática; a sensação de peso permanece ajustável nos exports.

## Inventário desta etapa

Modificados:
- project.godot; README.md.
- player/first_person_player.gd; player/player.tscn.
- parts/automotive_part.gd; parts/wheel_prototype.tscn.
- vehicles/part_socket.gd; vehicles/wheel_socket.tscn; vehicles/car_prototype.tscn.
- systems/part_carrier.gd; systems/interaction_controller.gd.
- systems/tests/prototype_test.gd.
- ui/interaction_hud.gd; ui/interaction_hud.tscn.
- world/garage_test.tscn.

Criados:
- README_DEV.md.
- systems/grabbable.gd; systems/interaction_target.gd; systems/interaction_audio.gd;
  systems/snap_socket.gd.
- systems/save/scene_registry.gd; systems/save/snapshot_codec.gd;
  systems/save/scene_snapshot.gd; systems/save/snapshot_validator.gd;
  systems/save/save_system.gd.
- systems/tests/mechanics_checks.gd; systems/tests/persistence_checks.gd.
- vehicles/fasteners/fastener_spec.gd; vehicles/fasteners/fastener.gd;
  vehicles/fasteners/wheel_bolt.tscn.
- tools/tool_spec.gd; tools/tool.gd; tools/wrench.tscn; tools/tool_slot.gd;
  tools/tool_slot.tscn; tools/toolbox.gd; tools/toolbox.tscn.
- world/garage_session.gd.

O Godot também gera arquivos .gd.uid correspondentes aos scripts novos.
Logs, probes e capturas de validação ficam apenas em .godot, ignorada pelo Git.
