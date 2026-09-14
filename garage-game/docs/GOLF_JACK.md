# Suspensão e macaco — continuação de setembro de 2026

Trabalho no projeto atual, sem recriar o carro, os sockets, as ferramentas ou
o save. Backup completo anterior em
`C:/GarageGame-backups/suspension-before-jack-20260913/garage-game`.
O relatório anterior `GOLF_SUSPENSION.md` é histórico; esta etapa audita o uso
real da suspensão, não apenas as transições de estado por código.

## Macaco e apoio

O macaco é uma `AutomotivePart` própria (`hydraulic_floor_jack`), com modelo
original editável `blender/source/floor_jack.blend`, export `floor_jack.glb`,
quatro roletes, chassi, alavanca, braço, prato articulado e conjunto hidráulico.
LMB pega e mantém; G solta ou encaixa no ponto próximo correto. Ele permanece
nivelado durante o transporte; sua escala física não é modificada.

Com o macaco posicionado, mirar nele e usar scroll ↑/↓ levanta/baixa suavemente.
Limite de elevação do ponto: 0,30 m; serviço liberado a partir de 0,13 m.
O macaco carregado não pode ser retirado. A descida final exige a roda
reinstalada e apertada; a regra é reavaliada durante o movimento.

`VehicleJackSupport` conserva o carro rígido, gira sobre o apoio dos pneus do
lado oposto e corrige a translação com amostras convexas dos pneus importados.
O chassi do macaco fica no chão e rola horizontalmente para acompanhar o arco
do braço. Não existe collider invisível sustentando o carro no ar.

Pontos medidos na superfície inferior original, em coordenadas Godot locais:

| Ponto | X | Y | Z |
|---|---:|---:|---:|
| FL | 0,77 | 0,147048 | 0,69 |
| FR | -0,77 | 0,147048 | 0,69 |
| RL | 0,77 | 0,158451 | -0,80 |
| RR | -0,77 | 0,158451 | -0,80 |

## Interação e persistência

- Peças removidas pertencem à garagem, não ao nó móvel do carro.
- Sockets vazios não ocultam freios/mangas da mira; ficam selecionáveis
  durante o transporte de uma peça compatível.
- R + scroll também ajusta o alcance das chaves para os slots da bancada;
  a pose normal de mão permanece inalterada.
- F3 inclui peças soltas, sockets e colliders do macaco.
- O schema 3 e `garage_suspension_v1.json` foram mantidos. Saves anteriores
  recebem apenas o pacote inicial do macaco, sem substituir peças antigas.
- Save/load valida a associação entre macaco e ponto antes de alterar a cena.
  F8 restaura o snapshot inicial, incluindo carro no chão e posição do macaco.

## Correções de encaixe 3D

As pinças dianteiras tiveram mandíbula externa, ponte e detalhes reposicionados
para liberar o aro. Discos traseiros foram deslocados 6 mm para dentro,
preservando seus 256 × 22 mm; braços longitudinais traseiros e suas buchas
receberam ajuste de folga. Colliders compostos/anulares preservam os furos dos
discos, molas e mangas, em vez de fechá-los com um único casco convexo.
Os dois parafusos superiores de 13 mm de cada strut foram separados do
rolamento/retentor central e apoiados numa chapa anular própria. A auditoria
focada desses dois componentes atualizados também não encontrou interseções
contra carroceria/pneus/aros. Total atual: 227.016 triângulos nas 46 peças.

As caixas de roda originais eram fechadas nas passagens dos componentes.
Recortes de serviço foram feitos somente nas superfícies internas do derivado,
preservando a carroceria exterior e os painéis articulados; não se oculta a
caixa de roda inteira. O ZIP/FBX e o arquivo de referência original não mudaram.

A auditoria `audit_golf_suspension_packaging.py` encontrou zero pares de
interseção de triângulos das 46 peças contra carroceria, pneus e aros na pose
montada. Isso verifica esse escopo geométrico, não substitui o teste de
desmontagem nem afirma ausência de contato nas juntas mecânicas entre peças.

## Validação desta etapa

O controle nativo da janela não estava disponível (`native pipe unavailable`).
O runner `systems/tests/golf_jack_player_cycle.gd` envia teclado e mouse ao
pipeline normal do Godot: WASD, mira, LMB, G, R + scroll, scroll e F2/F9.
Consultas somente de leitura ajudam a localizar alvos; o runner não teleporta
peças, não chama pickup/place diretamente e não altera aperto ou instalação.
Retomadas usam o save normal após o obstáculo, sem repetir etapas concluídas.

Confirmados nesta sessão: pegar/posicionar/levantar o macaco, save/load mantendo
apoio, remover roda FL, pinça, disco, semieixo, cubo, terminal, bieleta, pivô e
strut com ferramentas; os parafusos superiores corrigidos e o retentor da mola
fora do carro aceitaram a chave correta.

**Validação parcial — ciclo FL completo não aprovado.** Em 14/09 o usuário pediu
para interromper testes demorados na engine. A sessão foi encerrada, preservando
o checkpoint isolado. Não foram concluídas a retirada da mola/manga/bandeja, a
remontagem completa, a descida final e o reset pelo fluxo do jogador. Esses
caminhos estão implementados, mas não devem ser apresentados como aprovados.
O runner ainda precisa de melhoria de navegação para itens soltos perto da
bancada/parede; suas falhas de rota não comprovam uma falha mecânica da peça.
Não executar o ciclo longo automaticamente: preferir revisão de código e
checagens pontuais curtas, conforme a preferência atual do usuário.

Publicação: uma cópia somente com arquivos públicos foi importada e iniciada
headless por três frames, sem erros de parser/recurso. O aviso visual de asset
ausente não foi inspecionado nessa checagem. A importação no ambiente completo
emitiu avisos/erros de liberação de recursos ao encerrar o editor, sem erro de
parser na execução do gameplay; a origem desses avisos não foi investigada.

## Limitações deliberadas

O suporte é estável e cinemático, não física veicular completa: o lado atendido
acompanha a carroceria sem simulação individual de droop/compressão. Só o ponto
ativo libera a remoção da respectiva roda. Os agregados são compartilhados;
não são retirados no ciclo de um único canto com o lado oposto conectado.
A compressão da mola fora do carro permanece abstraída no protótipo existente.
O comportamento do conjunto strut/mola solto após save/load ainda merece revisão:
houve deslocamento durante a navegação do teste, mas a telemetria final mostrou
repouso, sem hold ativo. Não foi comprovado se veio de contato com o jogador ou
da hierarquia de corpos físicos aninhados; não foi aplicada correção especulativa.
Não se trata de orientação para manutenção de um veículo real.

O Golf e seus derivados continuam locais e não são publicados no Git.
O executável antigo não foi reexportado nesta etapa.
