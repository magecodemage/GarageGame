# README_DEV — GarageGame

## Escopo e execução

Este protótipo Godot 4.7.2 demonstra manutenção automotiva em uma garagem usando
somente GDScript e meshes primitivas. A cena principal é
`res://world/garage_test.tscn`; F5 executa o projeto e F6 executa a cena aberta.

O carro ainda não dirige. Não existem cidade, NPCs, economia, motor interno,
circuito elétrico completo nem assets externos.

## Controles

- WASD: mover.
- Mouse: câmera.
- Espaço: pular.
- Ctrl: agachar.
- LMB segurado: pegar/manter peça ou ferramenta; soltar instala ou deixa cair.
- RMB + mouse: girar o item carregado.
- R + roda do mouse: ajustar distância do item.
- Roda do mouse sobre fastener: apertar/afrouxar um nível.
- P: pausa.
- F2/F9: salvar/carregar.
- F3: debug do alvo.
- F8: reset da garagem.
- Esc: liberar o mouse.

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
systems/save/           registro, snapshot, validação e save
tools/                  ferramentas, slots e toolbox
vehicles/               sockets, fasteners e conjuntos do veículo
world/                   garagem e atalhos da sessão
ui/                      HUD e mensagens temporárias
```

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

`vehicles/front_left_assembly.tscn` contém:

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
14, 15, 17 e 19 mm; portanto cobre todas as novas fixações.

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

O schema 2 usa `user://garage_slice_v2.json`. Ele persiste:

- pose, pitch e agachamento do jogador;
- ID, transform, socket, estado instalado/armazenado, condição, desgaste e
  metadata de cada item;
- `custom_state` de bateria, radiador, filtro, alternador e motor de partida;
- tightness, presença e lock de cada fastener;
- estado da toolbox.

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
e lock.

## Validação

Na raiz do projeto:

```text
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script res://systems/tests/prototype_test.gd
```

O runner verifica InputMap, movimento, pulo, crouch, IDs, sockets, dependências,
tipos, ferramenta errada/correta, estados mecânicos, os onze testes de aceitação,
save/load parcial e reset. O resultado também é gravado em
`.godot/slice_test_result.json`. Warnings produzidos pelos dois snapshots
inválidos são esperados; erros de parser/runtime não são.

Ainda precisam de avaliação manual: conforto da sensibilidade, precisão ao mirar
em fasteners próximos, sensação de peso/jitter, manipulação junto ao jogador e
paredes e legibilidade do HUD em diferentes resoluções.
