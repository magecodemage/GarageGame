# README_DEV — GarageGame

## Escopo e execução

Este protótipo Godot 4.7.2 demonstra manutenção automotiva em uma garagem.
A cena de desenvolvimento atual é `res://world/garage_golf_test.tscn`;
F5 passa pela entrada `world/project_entry.tscn`, que abre essa mesma garagem
com os recursos locais ou mostra instruções quando estão ausentes. Não há
substituição automática pelo carro legado. F6 executa a cena aberta. O Golf é referência temporária
não comercial. A cena anterior permanece disponível e o backup completo
anterior à integração fica em `C:/GarageGame-backups/golf-before-integration-20260911-204102`.
Leia [docs/GOLF_SUSPENSION.md](docs/GOLF_SUSPENSION.md) para a etapa atual:
46 componentes de suspensão desmontáveis, duas portas reais e hatch articulados.
[docs/GOLF_INTEGRATION.md](docs/GOLF_INTEGRATION.md) registra a integração anterior.
O backup anterior à suspensão está em `C:/GarageGame-backups/suspension-before-20260912`.
O backup anterior ao macaco está em `C:/GarageGame-backups/suspension-before-jack-20260913`.
Veja [docs/GOLF_JACK.md](docs/GOLF_JACK.md) para apoio, serviço FL e limitações,
e [docs/GIT_REFERENCE_SETUP.md](docs/GIT_REFERENCE_SETUP.md) para preparar um clone
sem redistribuir o modelo de referência. Nenhum `AGENTS.md` foi encontrado na árvore atual.

O carro ainda não dirige. Não existem cidade, NPCs, economia, motor interno,
circuito elétrico completo nem física final de direção.

## Controles

- WASD: mover.
- Mouse: câmera.
- Espaço: pular.
- Ctrl: agachar.
- LMB uma vez (`grab_item`): pegar e manter peça ou ferramenta.
- G (`drop_item`): soltar; instala somente quando há socket válido destacado.
- RMB + mouse: girar o item carregado.
- R + roda do mouse: ajustar distância do item.
- Roda do mouse sobre fastener: apertar/afrouxar um nível.
- Macaco posicionado: scroll ↑ levanta, scroll ↓ baixa; LMB pega e G encaixa/solta.
- Rodas só saem com o canto adequadamente apoiado e seus cinco parafusos soltos.
- P: pausa.
- F2/F9: salvar/carregar.
- F3: debug do alvo e overlay de origens visuais/sockets/colliders/fasteners no Golf.
- F8: reset da garagem.
- Esc: liberar o mouse.
- T: entrar/sair do modo temporário de teste do motor.
- I: alternar ignição OFF/IGNITION dentro do modo de teste.
- K segurado: posição START; soltar retorna a IGNITION.
- W: acelerador somente no modo de teste; fora dele continua sendo movimento FPS.
- F7: adicionar 5 litros de combustível para debug.

## Arquitetura

`Grabbable` mantém a física comum de peças e ferramentas. `AutomotivePart`
adiciona identidade, condição, estado, dependências, pose de instalação e estado
de fixação. `SnapSocket` implementa encaixe por proximidade e tipo; `PartSocket`
adiciona fasteners e compatibilidade entre tipos de peça e socket.

O `Player` coordena entrada por `InteractionController` e hold por `PartCarrier`.
Ele não conhece roda, bateria, disco ou qualquer outra peça concreta.
`InteractionTarget` adapta os colliders para uma interface comum de interação.

Os diretórios relevantes são:

```text
player/                 personagem e câmera
parts/                  base e cenas de peças
systems/mechanics/      dependências declarativas
systems/electrical/     fundação elétrica reutilizável
systems/engine/         motor, ignição, fluidos, diagnóstico e áudio
systems/vehicle/        base persistente de sistemas do veículo
systems/save/           registro, snapshot, validação e save
tools/                  ferramentas, slots e toolbox
vehicles/               sockets, fasteners e conjuntos do veículo
world/                   garagem e atalhos da sessão
ui/                      HUD e mensagens temporárias
blender/                 fonte, export, previews e geradores do carro
```

## Carro visual intermediário (legado preservado)

`vehicles/car_visual.tscn` carrega `blender/exports/car_main.glb` com
`GLTFDocument` como camada visual do `CarPrototype`. Isso evita depender de um
cache de import já existente em checkouts limpos. O chassi, o estado mecânico,
os sockets, as colisões e
as peças interativas continuam no Godot. `CarVisualBridge` abre o capô visual e
oculta no GLB a roda dianteira esquerda, seu conjunto de freio/suspensão e os
componentes do cofre que já possuem uma instância funcional no gameplay. Assim,
remover uma dessas peças não deixa uma cópia visual fixa.

O asset é um hatch fictício inspirado somente nas proporções e arquitetura de
hatches europeus de 2000–2005. Não contém marca, emblema ou badge real. A escala
é métrica, a frente do arquivo Blender aponta para `-Y` e a conversão glTF a
alinha com `+Z` na cena atual do Godot.

Arquivos principais:

```text
blender/source/car_main.blend       fonte editável
blender/exports/car_main.glb        asset usado pelo Godot
blender/previews/*.png              vistas de validação
blender/scripts/build_car.py        geração idempotente completa
blender/scripts/validate_model.py   nomes, escala, pivôs e triângulos
```

Para reconstruir com a instalação detectada nesta máquina:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --python blender/scripts/build_car.py
```

Os módulos `create_body.py`, `create_wheels.py`, `create_interior.py`,
`create_engine_bay.py`, `create_mechanical_parts.py` e `create_sockets.py`
podem ser alterados separadamente. `car_dimensions.py` concentra as dimensões e
posições dos eixos. O build limpa somente a cena Blender que está gerando,
recria os objetos com nomes estáveis, valida, salva o `.blend`, renderiza os
previews e exporta o GLB.

## Dependências mecânicas

`MechanicalDependencySet` é um `Resource` anexado à peça e referencia IDs
persistentes. Ele oferece:

- `required_parts_installed`: peças que precisam estar instaladas para instalar;
- `required_parts_removed`: peças que precisam estar fora para instalar;
- `blocking_parts`: peças instaladas que impedem a remoção;
- `required_fasteners_loose`: fasteners que precisam estar em tightness zero.

`AutomotivePart.can_install()` e `can_remove()` retornam um dicionário com
`allowed: bool` e `reason: String`. O HUD usa o mesmo resultado, portanto a regra
e a explicação não são duplicadas no controller. Fasteners do próprio socket são
verificados automaticamente antes das dependências declaradas.

A ordem de desmontagem do canto dianteiro esquerdo nasce desses dados: parafusos
da roda → roda → parafusos da pinça → pinça → disco. Não existe lista de passos
no Player.

## Estados mecânicos

Estados de `AutomotivePart`: `FREE`, `HELD`, `PLACED`,
`PARTIALLY_FASTENED` e `FASTENED`.

- `is_secure()`: instalada e com toda a fixação completa;
- `is_partially_secure()`: instalada com ratio entre zero e um;
- `is_loose()`: instalada sem aperto;
- `get_fastening_ratio()`: soma do tightness dividida pelo máximo possível.

`VehicleMechanicalState` indexa o veículo pelos IDs e fornece
`get_missing_critical_parts()`, `get_loose_parts()`,
`get_partially_secure_parts()` e `get_vehicle_readiness()`. A prontidão varia de
0.0 a 1.0 e serve apenas para consulta futura; não bloqueia gameplay.

## Conjuntos e IDs

`vehicles/front_left_assembly.tscn` (legado) contém:

| Peça | ID | Socket | Fasteners |
|---|---|---|---|
| Amortecedor | `front_left_strut` | `front_left_strut_socket` | 13 e 17 mm |
| Cubo | `front_left_hub` | `front_left_hub_socket` | 2 × 17 mm |
| Disco | `front_left_brake_disc` | `front_left_brake_disc_socket` | 2 × 10 mm |
| Pinça | `front_left_brake_caliper` | `front_left_brake_caliper_socket` | 2 × 13 mm |
| Roda | `front_left_wheel` | `front_left_wheel_socket` | 5 × 19 mm |

`vehicles/engine_bay_prototype.tscn` contém:

| Peça | ID | Socket | Fasteners |
|---|---|---|---|
| Bateria | `battery` | `battery_mount` | 2 × 10 mm |
| Radiador | `radiator` | `radiator_mount` | 2 × 12 mm |
| Caixa do filtro | `air_filter_box` | `air_filter_mount` | 2 × 8 mm |
| Alternador | `alternator` | `alternator_mount` | 14 e 17 mm |
| Motor de partida | `starter_motor` | `starter_mount` | 12 e 14 mm |

Todos os IDs de peça, socket, fastener, ferramenta, slot e toolbox são estáveis
e únicos na cena. A toolbox atual fornece chaves 6, 7, 8, 9, 10, 11, 12, 13,
14, 15, 17 e 19 mm no legado. A variante atual acrescenta 16, 18 e 21 mm,
mantendo os IDs e tamanhos anteriores.

Na variante Golf, os sockets são reposicionados pelos centros geométricos
reais. Há quatro rodas independentes e 20 parafusos de 17 mm. Os IDs da FL
foram preservados; FR/RL/RR ganham IDs próprios. A frente é +Z e a esquerda
do veículo é +X. A tabela acima documenta apenas o conjunto legado.

## Fundação elétrica e propriedades futuras

`ElectricalComponent` guarda `component_id`, `is_connected` e `condition`, além
de captura, restauração e validação de estado. Ainda não calcula corrente.

`BatteryPart` expõe `voltage` (12.6), `charge`, `condition`,
`battery_positive_terminal` e `battery_negative_terminal`. O socket
`battery_mount` e seus fasteners bloqueiam a remoção enquanto apertados.

`AlternatorPart` expõe `belt_connected`, `electrical_connected` e `condition`.
`StarterMotorPart` expõe `electrical_connected` e `condition`.
`RadiatorPart` guarda `coolant_capacity`, `coolant_amount` e a condição herdada.
`AirFilterBoxPart` guarda `air_filter_condition`.

Os terminais da bateria são ligados aos fasteners
`battery_positive_terminal_fastener` e `battery_negative_terminal_fastener`.
Tightness acima de zero representa conexão elétrica. A classe
`ElectricalComponent.bind_fastener()` permite reutilizar o mesmo mecanismo em
luzes, velas e outros componentes futuros.

## Motor funcional

`EngineController` é um `VehicleRuntimeSystem` configurado por referências de
sistema e IDs de peças. Ele nunca procura NodePaths concretos internamente.
Estados: `OFF`, `CRANKING`, `RUNNING`, `STALLED` e `FAILED`.

A partida passa por `can_crank()` e `can_engine_start()`. O starter só gira com
bateria e starter instalados/conectados e carga acima do limite crítico. Após
`minimum_crank_time`, o motor só pega se houver RPM de partida suficiente,
combustível, ignição e todas as peças de `engine_critical_part_ids`.

`EngineStartDiagnostic` centraliza códigos e mensagens:

- `NO_BATTERY`;
- `BATTERY_DISCONNECTED`;
- `LOW_BATTERY`;
- `NO_STARTER`;
- `STARTER_DISCONNECTED`;
- `NO_FUEL`;
- `NO_IGNITION`;
- `CRITICAL_PART_MISSING`.

Para adicionar futuramente uma peça que impeça partida, dê a ela um ID estável,
inclua esse ID em `VehicleMechanicalState.engine_critical_part_ids` e mantenha a
peça derivada de `AutomotivePart`. O diagnóstico e o controller passam a
considerá-la sem condicionais de classe no Player.

`IgnitionSystem` possui `OFF`, `ACCESSORY`, `IGNITION` e `START`. START só existe
enquanto a ação K está pressionada; captura e load normalizam START para
IGNITION. `EngineTestMode` isola os controles de bancada e desabilita movimento
FPS enquanto W representa throttle.

`FuelSystem` guarda litros, capacidade e tipo e consome conforme RPM.
`OilSystem` permite funcionamento com pouco óleo, mas retorna uma taxa de dano
conservadora. `CoolantSystem` é a fonte canônica do volume de coolant e sincroniza
o `RadiatorPart`. Com radiador e nível adequados a temperatura converge para a
faixa operacional; sem eles sobe rapidamente. Acima da temperatura crítica o
motor perde condição gradualmente.

A bateria possui carga normalizada, capacidade em Ah, tensão aproximada variável,
`consume_energy()` e `charge_battery()`. O starter consome 220 A durante crank.
O alternador produz corrente conforme RPM somente quando instalado, conectado e
com correia. Sem alternador o motor continua enquanto houver energia.

`EngineAudio` expõe slots vazios para starter, idle, running, shutdown e failed
starter. Nenhum arquivo de áudio externo foi incluído.

Sinais disponíveis: `engine_started`, `engine_stopped`, `engine_stalled`,
`engine_state_changed`, `rpm_changed`, `temperature_changed`,
`engine_condition_changed`, `alternator_output_changed`,
`battery_charge_changed`, `fuel_changed`, `ignition_state_changed` e
`starter_command_changed`. Valores contínuos só emitem quando ultrapassam um
limiar útil. Combustível, bateria, dano e temperatura são atualizados a 10 Hz;
somente estado/RPM usam physics process.

## Readiness

`VehicleMechanicalState` expõe avaliações separadas:

- `get_mechanical_readiness()`: presença e fastening ratio das peças críticas;
- `get_electrical_readiness()`: presença e conexão das peças elétricas;
- `get_engine_readiness()`: presença e segurança das peças essenciais do motor.

Essas métricas são consultas. As regras de partida usam os estados e diagnósticos
concretos, em vez de comparar uma porcentagem arbitrária.

## Como adicionar uma peça

1. Crie uma cena `RigidBody3D` com script derivado de `AutomotivePart`, meshes e
   collisions primitivas.
2. Defina `part_id`, `display_name`, `part_type`, `mass`,
   `compatible_socket_types`, `required_fasteners` e pose de instalação.
3. Quando necessário, crie um `MechanicalDependencySet` na cena e preencha IDs.
4. Crie um `PartSocket` com ID único, tipo compatível, `InstallationPoint`,
   preview, collision e `Fasteners`.
5. Para cada fastener, use um `FastenerSpec` com tipo, tamanho e aperto máximo;
   dê um `fastener_id` estável e único.
6. Se houver estado especializado, sobrescreva `get_custom_state()` e
   `apply_custom_state()` para torná-lo persistente.
7. Adicione a peça a `critical_part_ids` somente se ela participar da prontidão.
8. Rode a validação headless; dependências ou IDs desconhecidos são rejeitados.

Nenhuma condição sobre classes concretas deve ser adicionada ao Player ou ao
`InteractionController`.

## Save, load e reset

O schema 3 usa `user://garage_slice_v3.json` no legado. A suspensão atual usa
`user://garage_suspension_v1.json`, preservando o arquivo da etapa anterior.
Não há conversão silenciosa entre esses layouts. Ele persiste:

- pose, pitch e agachamento do jogador;
- ID, transform, socket, estado instalado/armazenado, condição, desgaste e
  metadata de cada item;
- `custom_state` de bateria, radiador, filtro, alternador e motor de partida;
- tightness, presença e lock de cada fastener;
- estado da toolbox.
- estado normalizado de ignição e motor, RPM, temperatura e condição;
- combustível, óleo e coolant;
- carga/capacidade/conexões da bateria e conexões de starter/alternador.

O load valida todo o snapshot antes de alterar a cena. A restauração libera
vínculos, posiciona objetos, reconecta sockets por ID, restaura fasteners e
recalcula os estados. Um hold em andamento nunca é persistido como botão preso.

F8 reaplica o snapshot inicial em memória e restaura player, peças, sockets,
fasteners, propriedades especializadas, toolbox e ferramentas.

## HUD e debug

O HUD normal mostra nome e estado mecânico de forma curta, por exemplo peça
solta, parcial ou quantidade de parafusos firmes. Tentativas inválidas geram uma
mensagem temporária: dependência, ferramenta incorreta, socket incompatível ou
distância insuficiente.

F3 acrescenta ID, classe de script, tipo, socket, estado, fastening ratio,
dependências e blocking parts. Fasteners mostram ferramenta, tamanho, tightness
e lock. O painel do veículo mostra Engine State, RPM, bateria, combustível, óleo,
coolant, temperatura, condição, starter, alternador, ignição e Start blockers.

## Validação

Na raiz do projeto:

```text
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script res://systems/tests/prototype_test.gd
```

O runner verifica InputMap, movimento, pulo, crouch, IDs, sockets, dependências,
tipos, ferramenta errada/correta, estados mecânicos, os testes mecânicos e os 14
testes do motor, save/load parcial e reset. O resultado também é gravado em
`.godot/slice_test_result.json`. Warnings produzidos pelos dois snapshots
inválidos são esperados; erros de parser/runtime não são.

Ainda precisam de avaliação manual: conforto da sensibilidade, precisão ao mirar
em fasteners próximos, sensação de peso/jitter, manipulação junto ao jogador e
paredes e legibilidade do HUD em diferentes resoluções.

## Histórico preservado: visual master da carroceria — fase 01

Esta seção registra uma fase anterior, não o fluxo atual. Não executar seus
scripts para substituir o Golf. O arquivo de trabalho atual da referência é
`blender/source/golf_reference_test.blend`, conforme `docs/GOLF_INTEGRATION.md`.

O protótipo procedural anterior continua preservado em `blender/source/car_main.blend`
e `blender/exports/car_main.glb`. Uma cópia congelada também existe em
`blender/backups/procedural_20260910/`. O script `blender/scripts/build_car.py`
é agora identificado como pipeline legado e continua escrevendo somente esses
arquivos antigos.

O novo arquivo definitivo para edição visual é
`blender/source/car_visual_master.blend`. Ele usa X para largura, Y para
comprimento (frente em -Y) e Z para altura. A cena está separada em
`REFERENCES`, `BODY`, `REMOVABLE_BODY`, `GLASS`, `INTERIOR`, `MECHANICAL` e
`HELPERS`; `LEGACY_PROTOTYPE` guarda o shell antigo oculto e
`VALIDATION_GUIDES` guarda contornos e limites de painéis que não aparecem nos
renders normais.

`body_shell_accuracy` é uma half-mesh em +X com Mirror como primeiro modificador
e Subdivision depois dele. A cage atual tem 471 vértices, 370 faces e 100% de
quads. Os arcos de roda pertencem à borda da própria carroceria. Para-brisa,
vidro traseiro e duas aberturas laterais por lado são vazios topológicos; os
pilares A/B/C e os trilhos do teto permanecem no mesmo shell.

As imagens originais fornecidas no chat não estavam disponíveis como arquivos
locais. Por isso `blender/references/generated_guides/` contém guias vetoriais
reconstruídas a partir do blueprint e das silhuetas fornecidas. Elas são planos
IMAGE não renderizáveis na collection `REFERENCES`; não são cópias redistribuídas
das fotografias.

Dimensões validadas:

| Medida | Valor |
|---|---:|
| Comprimento | 4,149 m |
| Largura | 1,735 m |
| Altura | 1,439 m |
| Entre-eixos | 2,511 m |
| Bitola dianteira | 1,513 m |
| Bitola traseira | 1,494 m |
| Centro das rodas em Z | 0,315 m |
| Limite inferior aproximado do shell | 0,335 m |

O fluxo novo é:

```text
referências -> car_visual_master.blend -> validação -> helpers -> export opcional -> Godot
```

`bootstrap_visual_master.py` foi usado uma vez para criar a cage inicial. Ele se
recusa a sobrescrever o master sem `--force-bootstrap` e não faz parte do fluxo
normal. A partir deste marco, a carroceria deve ser refinada diretamente no
`.blend`. `visual_master_pipeline.py` somente valida e renderiza; não recria a
geometria. `export_visual_master.py` é opcional e ainda não foi executado nem
integrado ao Godot nesta fase.

Para validar e atualizar os previews sem modificar a forma:

```text
blender --background blender/source/car_visual_master.blend --python blender/scripts/accuracy/visual_master_pipeline.py
```

O relatório fica em `blender/reports/body_accuracy.json`. Os previews ortográficos,
três-quartos e overlays dimensionais ficam em `blender/previews_accuracy/`.

**MANUAL MODELING RECOMMENDED:** antes de separar painéis, refine no objeto
`body_shell_accuracy` os loops do encontro capô/paralama e da face dianteira nas
vistas FRONT e FRONT_3Q; ajuste os loops do pilar A e da borda inferior do
para-brisa nas vistas SIDE e FRONT_3Q; refine os loops do pilar C, canto superior
do hatch e transição para o quarto traseiro nas vistas SIDE e REAR_3Q; e ajuste
a curvatura dos loops de lábio dos quatro arcos nas vistas SIDE/FRONT/REAR. As
correções devem aproximar os raios de canto, dar espessura final aos vãos e
remover a suavização genérica que ainda existe no blockout. Os contornos globais,
eixos e medidas devem permanecer fixos.

Esta fase termina na carroceria-base. Separação de capô, portas, hatch,
para-choques, faróis, vidros finais, interior, cofre e integração no Godot ficam
para uma fase posterior à aprovação dos renders.
