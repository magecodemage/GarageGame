# Golf R32 — suspensão desmontável e painéis

Registro histórico da etapa anterior. A revisão posterior de geometria,
serviço por entradas normais e macaco está em [GOLF_JACK.md](GOLF_JACK.md).

Etapa local concluída em 13/09/2026, com as limitações abaixo. Executar F5 no
projeto existente; a cena principal continua `world/garage_golf_test.tscn`.
Não foram recriados o Golf, o motor ou os sistemas de entrada/save. O executável
antigo na raiz não foi reexportado. Nenhum push foi feito nesta etapa.

## Geometria e arquitetura

46 VehicleParts novas (11 em cada canto + dois agregados compartilhados), com
226.248 triângulos. Cada peça tem root unitário e um visual Blender independente
com materiais preservados. Os centros dos sockets, colliders e parafusos vêm do
mesmo manifesto, sem adaptar/deformar a carroceria aos placeholders antigos.

| Conjunto | Peças independentes por lado |
|---|---|
| Dianteiro McPherson | amortecedor/strut, mola, manga de eixo, cubo/rolamento, disco, pinça, bandeja inferior, pivô, terminal de direção, bieleta, semieixo homocinético |
| Traseiro independente | manga/portador, cubo/rolamento, disco, pinça, mola separada, amortecedor, braço longitudinal, bandejas inferior e superior, bieleta, semieixo homocinético |
| Compartilhados | agregado dianteiro e agregado traseiro |

Molas são hélices, braços têm aberturas/reforços/buchas, amortecedores têm haste,
coifa e apoios, e semieixos têm juntas, coifas e abraçadeiras. Discos ventilados
de 334 × 32 mm na frente e 256 × 22 mm atrás; pinças com faces e pontes separadas.
As representações não são peças CAD OEM: são formas proporcionais para gameplay.

A arquitetura usa o material técnico Volkswagen [SSP 206, Golf 4MOTION](https://www.volkspage.net/technik/ssp/ssp/SSP_206.pdf).
As dimensões de freios seguem o [catálogo Brembo para Golf IV R32](https://www.bremboparts.com/europe/en/catalogue/vw-golf-iv-1j1-3-2-r32-4motion/000016846-1).
Não foi usado eixo de torção. Caixa de direção/barra dianteira acompanham o
agregado dianteiro; barra traseira e representação do diferencial/Haldex
acompanham o agregado traseiro, sem simulação nova de transmissão.

## Fixação e uso

88 fasteners novos de suspensão, além dos 20 parafusos das quatro rodas.
Tamanhos desta suspensão: **13, 16, 17, 18, 19 e 21 mm**. A toolbox conserva as
chaves do motor e adiciona os tamanhos ausentes.

- LMB uma vez pega; o objeto continua na mão sem manter o botão.
- G solta ou encaixa no socket correto próximo. LMB não solta o item.
- Scroll aperta/afrouxa somente com a ferramenta correta equipada.
- Encaixar uma peça aparafusada resulta em PLACED; apertar resulta em FASTENED.
- Sockets têm tipos exclusivos por componente e lado. O encaixe normaliza a
  rotação à pose montada; não conserva uma orientação invertida.
- F3 mostra origens, sockets, pontos dos colliders compostos e fasteners.
- Indicadores de encaixe só aparecem para um encaixe válido destacado ou F3.

As dependências são declarativas, não uma sequência rígida no Player. Exemplo
válido FL: roda, pinça, disco, semieixo, cubo, terminal, bieleta, pivô; soltar os
parafusos da união manga/strut; retirar strut, depois mola na bancada, manga e
bandeja. Terminal/bieleta admitem outras posições nessa ordem quando liberados.
Agregados são peças únicas comuns aos dois lados: não saem com os respectivos
braços/semieixos ainda conectados.

A mola dianteira acompanha fisicamente o strut pelo seu socket aninhado.
Seu retentor de 21 mm só é operável com o strut fora do carro; o conjunto não
reinstala com a mola sem retenção. **Compressão da mola é abstraída no protótipo**,
não uma instrução de manutenção real. A mola traseira não ganhou parafuso fictício:
retirar amortecedor e soltar a conexão exterior da bandeja permite removê-la.
Mola/portador traseiros derivam o estado de fixação das peças que os retêm.

## Painéis e interior

Foram separados os dois painéis laterais reais e o hatch a partir de ilhas da
mesh original, preservando faces/UV/pose fechada. Espelhos e forros acompanham
as portas; vidro, limpador, emblema e terceira luz acompanham o hatch. Lanternas
laterais ficam na carroceria. O capô original e seu controlador foram mantidos.

| Painel | Pivô Godot local | Ângulo |
|---|---|---|
| door_fl | (0,760; 0,700; 0,770) | −60° em Y |
| door_fr | (−0,760; 0,700; 0,770) | +60° em Y |
| hood | (0; 0,916; 0,868230) | −65° em X |
| trunk_hatch | (0; 1,350; −1,480) | +70° em X |

LMB abre/fecha com interpolação suave. Colliders simples acompanham as dobradiças.

O original não continha piso do bagageiro acima das molas. Foram acrescentadas,
como geometria fixa claramente identificada, chapa contornada de 1,5 mm, base
de 8 mm, revestimento de 1,2 mm, três nervuras, soleira e faces internas das caixas
de roda (9 meshes; 734 triângulos). Piso acabado a 0,605 m; chapa inferior a
0,594 m, acima do topo das molas em aproximadamente 0,562 m. Nenhuma mola foi
abaixada, achatada ou escondida pelo código. Os pequenos apoios superiores dos
amortecedores ainda aparecem acima das caixas internas; faltam suas tampas finais.

## Save e preservação

`SaveSystem`, registro e schema 3 existentes persistem as 46 peças, sockets,
poses soltas, aperto e os estados de portas/capô/hatch. F2 salva, F9 carrega e F8
reaplica o snapshot inicial com peças, ferramentas, painéis e player restaurados.
Arquivo novo: `user://garage_suspension_v1.json`. O `garage_slice_v3.json` anterior
é preservado, mas não é migrado automaticamente para esta topologia diferente.

Backup integral pré-etapa: `C:/GarageGame-backups/suspension-before-20260912`.
Fonte original `golf_reference_test.blend`, FBX e ZIP preservados. A cena antiga
`car_golf_integrated.tscn` continua disponível. Derivados Golf permanecem locais,
de referência não comercial; não foram publicados nem incluídos em release.

## Verificação limitada

Foram executados somente os quatro grupos pedidos, sem rodar as suítes antigas:

1. FL: 11 componentes e roda retirados/reinstalados, uso das chaves pela API real,
   estado PLACED antes do aperto, queda física e alinhamento dos sockets.
2. FR/RL/RR: mesmos scripts/registry, 11 peças por canto, compatibilidade exclusiva
   e pose instalada. Não foi repetida a desmontagem completa em cada lado.
3. Save/load parcial: roda, pinça e disco removidos, poses/bolts e porta aberta
   restaurados; mola aninhada preservada; reset reaplicado.
4. Duas portas **existentes**, capô e hatch: interação, interpolação, pivô estável,
   retorno à pose fechada e revisão das capturas. Não se testaram quatro portas
   porque a mesh não contém as duas traseiras.

Correções verificadas pontualmente: acesso dos parafusos da pinça dianteira e
flange da junta interna, retenção das molas e dependência da bieleta traseira.
Os checks automatizados usam fixtures de posicionamento e APIs de gameplay;
não substituem uma sessão manual de transporte/mira em todos os cantos.
Não foi feito stress test prolongado de física, ergonomia ou desempenho.

Runner: `systems/tests/golf_suspension_essential.gd`. `--case=1..4` executa apenas
o grupo afetado; `--visual` captura imagens; `--review` só atualiza as imagens.
Capturas estão em `blender/previews_suspension/`: `all_installed.png`,
`front_suspension.png`, `rear_suspension.png`, `panels_closed.png`,
`panels_open_front.png`, `panels_open_rear.png`, `suspension_layout_body_hidden.png`.
A última é uma vista técnica explicitamente sem a carroceria, não a aparência do jogo.

## Arquivos desta etapa

Criados:

- `blender/scripts/build_golf_suspension.py`, `golf_suspension_front.py`,
  `golf_suspension_rear.py`, `separate_golf_panels.py`.
- `blender/source/golf_suspension_work.blend`, `golf_reference_panels.blend`;
  `blender/exports/golf_suspension_parts.glb`, `golf_reference_panels.glb`.
- `blender/reports/golf_reference_panels.json`, `vehicles/golf_suspension_manifest.json`.
- `vehicles/golf_suspension_builder.gd`, `golf_suspension_part.gd`,
  `golf_suspension_fastener.gd`, `golf_suspension_vehicle.gd`,
  `golf_body_panel.gd`, `golf_panel_target.gd`, `car_golf_suspension.tscn`.
- `tools/golf_suspension_toolbox.gd`, `golf_suspension_toolbox.tscn`.
- `systems/tests/golf_suspension_essential.gd`, esta documentação e capturas.

Modificados: `world/garage_golf_test.tscn`, `vehicles/golf_alignment_debug.gd`,
`README_DEV.md`, `.gitignore` da raiz. Arquivos `.uid` são metadados Godot.
Outras alterações já presentes no worktree foram preservadas, não revertidas.

Os scripts Blender regeneram apenas seus derivados de trabalho; antes de
regenerar, salve à parte qualquer edição manual feita nesses derivados.

## Limitações restantes

- **O asset é hatch de três portas: duas laterais + hatch.** `door_rl/door_rr`
  não existem. Implementá-las exigiria modificar a carroceria ou trocar o asset,
  contrariando a preservação solicitada sem uma nova decisão do usuário.
- Sem compressor de mola interativo, suspensão dinâmica, direção ou simulação
  de transmissão 4MOTION; o carro continua fixo para manutenção.
- Barras estabilizadoras, caixa de direção e diferencial não se separam dos
  agregados nesta etapa. Rolamento acompanha o cubo; pastilhas acompanham a pinça.
- Ainda faltam vedações/fechaduras/gas struts e acabamento das tampas superiores
  traseiras. Cofre/motor mantém as representações temporárias da etapa anterior.
- Precisão de mira e transporte físico junto à carroceria precisam de avaliação
  manual prolongada; os testes desta etapa foram deliberadamente reduzidos.
