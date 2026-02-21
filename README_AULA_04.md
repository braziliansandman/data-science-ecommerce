# Tutorial para o projeto de E-commerce (Olist)

## Introdução

Este projeto trata de uma empresa de e-commerce: a Olist.
Se desejar saber um pouco mais sobre esta empresa, pode acessar o site dela: https://olist.com/.

A Olist disponibilizou um conjunto de dados reais (um *dataset*) no site do Kaggle.
Podemos ter uma noção melhor dos dados disponíveis da Olist no Kaggle se acessarmos: 

- https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

Vamos começar dando uma olhada sobre o que o Kaggle nos informa sobre estes dados.

Nós  iremos trabalhar com o dataset deste projeto ao longo de várias aulas para resolvermos diversos problemas de negócio!

## Instruções

### Preparando o projeto no VS-Code no seu computador

1. Verifique que o *Docker Desktop* esteja rodando em seu computador. 
1. Baixe o arquivo ZIP com este projeto acessando o GitHub em:
    - https://github.com/braziliansandman/data-science-ecommerce
1. Descomprima este arquivo ZIP em seu computador na mesma pasta dos demais projetos desta disciplina. 
    - CUIDADO: ao descomprimir, tome cuidado para não criar "uma pasta dentro de uma pasta". Isto resultaria em problema no desenvolvimento do projeto, porque você estaria com uma estrutura de pastas diferentes do seu professor. Os comandos não irão funcionar se a estrutura for diferente!
1. Abra o VS Code. 
    - NÃO CLIQUE NO BOTÃO "Reopen Container"! 
    - Provavelmente o VS Code vai abrir a pasta do último projeto que você estava trabalhando.
    - Você só precisa selecionar *File -> Open Folder* e navegar até encontrar e selecionar a *pasta* onde você descomprimiu este projeto.
    - Para ter certeza de que está tudo certo, verifique se a sua estrutura de pastas e arquivos está idêntica ao de seu professor comparando a visão do `Explorer` do seu VS Code com o dele.
    - Agora sim, poder acionar o comando `Reopen Container`.

### Realizando o setup do Postgres e do pgAdmin

Para esta aula, vamos usar novamente uma base de dados SQL (Postgres) e uma interface administrativa (pgAdmin) para rodar queries em SQL. Mas para fazermos isto, é preciso realizarmos um rápido setup destas duas ferramentas.

1. Acesse o pgAdmin em http://localhost:5051.
   - Login: `admin@local.dev`
   - Senha: `admin`
1. Com muita atenção, no pgAdmin:
    - Selecione o ícone `Servers` à esquerda e selecione o botão direito do mouse. Selecione `Register`, então `Server...`.
    - Na aba `General`, informe/digite:
        - `Name`, digite `db`.
        - Server group: selecione `Servers` (se já não estiver selecionado).
    - Selecione a aba `Connection` para informar os seguintes valores:
        - Host name/address: `db`
        - Port: `5432`
        - Maintenance database: `ecommerce`
        - Username: `postgres`
        - Password: `postgres`
    - Clique então no botão `Save`.
1. Verifique no pgAdmin:
   - Query Tool Workspace -> `SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;`
    - Esta consulta não deve retornar nenhuma tabela, porque ainda não foram criadas. É apenas para testar se pgAdmin + Postgres estão funcionando.

#### FAQ rápido
- `localhost:5051` não abre e a porta já está em uso:
   - troque para `5052:80` em `.devcontainer/docker-compose.yml`
   - recrie os serviços com `docker compose -f .devcontainer/docker-compose.yml up -d --force-recreate pgadmin`
   - acesse `http://localhost:5052`
- O navegador força HTTPS e quebra o acesso:
   - use explicitamente `http://127.0.0.1:5051/login`
   - tente aba anônima ou outro navegador

 ### Baixar os dados para este projeto

1. Nós poderíamos baixar todos os dados da Olist diretamente do Kaggle. Mas para fazer isto, seria preciso se cadastrar no Kaggle, criar uma chave de API e criar um script python (se desejar, você pode fazer isto mais tarde para treinar). 
1. Para esta aula, você pode acessar os mesmos dados do Olist, se baixar o arquivo `datasets.zip` disponível no módulo da Aula-04 no Canvas.
1. Baixe `datasets.zip` na raiz da pasta do projeto.
1. Em seguida, descompacte na pasta `datasets`. Verifique se a estrutura de arquivos ficou idêntica ao do professor.
1. Repare que todos os arquivos de dados estão no formato `CSV`. Experimente e visualize alguns arquivos para tomar contato com os dados. Note que alguns arquivos nÃo podem ser visualizados no VS Code por causa do tamanho.


### Carga do dataset Olist no Postgres

Após subir o devcontainer, execute na raiz do projeto:

- `bash scripts/olist/load_olist.sh`

O script cria/recria as 9 tabelas do schema `ecommerce`, importa os CSVs de `datasets/` e aplica as FKs (chaves estrangeiras) ao final da carga.

#### Troubleshooting rápido

- Erro `psql: command not found`:
    - faça `Dev Containers: Rebuild and Reopen in Container` para usar a imagem atualizada com `postgresql-client`.
- Erro de conexão com Postgres:
    - valide o `.env` (ou variáveis `PG*`) e confirme no pgAdmin: host `db`, porta `5432`, database `ecommerce`, usuário `postgres`.

### Construção da camada estrela (star schema)

Com a base relacional já carregada, execute na raiz do projeto:

- `bash scripts/olist/star/build_star.sh`

Esse processo cria/recria apenas as tabelas estrela no schema `ecommerce` (`d_*` e `f_*`), popula dimensões e fatos, cria índices e roda checks finais.

Checks esperados ao final:

- `f_order` com a mesma contagem de `ecommerce.orders` (delta `0`)
- `f_order_item` com a mesma contagem de `ecommerce.order_items` (delta `0`)
- `sum(gmv_items)` igual a `sum(order_items.price)` (delta `0.00`)
- `sum(payment_total)` igual a `sum(order_payments.payment_value)` (delta `0.00`)


