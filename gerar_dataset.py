#!/usr/bin/env python3
"""
Gerador do dataset Rota do Perfume — Imersão Jornada de Dados, agosto/2026.

Distribuidora B2B de perfumaria árabe. Importa e distribui no Brasil para
perfumarias, farmácias, lojas de shopping, revendedoras autônomas e e-commerces.
Empresa em crescimento acelerado. 24 meses de operação.

Gera 10 CSVs divididos em dois sistemas de origem:
  ERP  → produtos, pedidos, itens_pedido, pagamentos, estoque
  CRM  → clientes, vendedores, carteira, oportunidades, visitas

O dataset tem sujeira PROPOSITAL (ver SUJEIRA no fim do arquivo).
Seed fixa: mesmo resultado para todo mundo.

Uso:  python gerar_dataset.py [--saida ./dados] [--seed 42]
"""

import argparse, csv, os, random, unicodedata
from datetime import date, timedelta, datetime
from decimal import Decimal, ROUND_HALF_UP

# ----------------------------------------------------------------------
# PARÂMETROS
# ----------------------------------------------------------------------
INICIO = date(2024, 9, 1)
FIM    = date(2026, 8, 31)
N_CLIENTES   = 3000
N_VENDEDORES = 42
N_PRODUTOS   = 320

# ----------------------------------------------------------------------
# CATÁLOGOS
# ----------------------------------------------------------------------
SEGMENTOS = ['Perfumaria', 'Farmácia', 'Loja de shopping', 'Revendedora autônoma',
             'E-commerce', 'Salão de beleza', 'Loja de departamento', 'Quiosque']

CIDADES = [
    ('São Paulo','SP','Sudeste'),      ('Rio de Janeiro','RJ','Sudeste'),
    ('Belo Horizonte','MG','Sudeste'), ('Curitiba','PR','Sul'),
    ('Porto Alegre','RS','Sul'),       ('Salvador','BA','Nordeste'),
    ('Recife','PE','Nordeste'),        ('Fortaleza','CE','Nordeste'),
    ('Brasília','DF','Centro-Oeste'),  ('Goiânia','GO','Centro-Oeste'),
    ('Campinas','SP','Sudeste'),       ('Manaus','AM','Norte'),
]

BAIRROS = ['Centro','Jardins','Moema','Savassi','Batel','Boa Viagem','Meireles',
           'Barra','Asa Sul','Setor Bueno','Cambuí','Ipanema','Pinheiros',
           'Vila Madalena','Aldeota','Pituba','Bela Vista','Higienópolis']

CATEGORIAS = {
    # nome: (marcas, preco_min, preco_max, margem)
    'Eau de Parfum':      (('Nadir','Sahra','Layali','Mizan','Qamar','Rihan','Dahab'),  89.00, 420.00, 0.44),
    'Óleo Concentrado':   (('Nadir','Sahra','Attar Real','Mizan','Zahir'),              45.00, 260.00, 0.52),
    'Bakhoor':            (('Sahra','Dahab','Bayt Al Oud','Qamar'),                     28.00, 180.00, 0.48),
    'Difusor de Ambiente':(('Layali','Bayt Al Oud','Mizan'),                            62.00, 210.00, 0.41),
    'Body Splash':        (('Rihan','Layali','Nadir','Zahir'),                          32.00,  98.00, 0.38),
    'Kit Presente':       (('Nadir','Sahra','Layali','Dahab'),                         120.00, 690.00, 0.35),
    'Hidratante Corporal':(('Rihan','Layali','Zahir'),                                  29.00,  86.00, 0.36),
    'Incenso':            (('Bayt Al Oud','Sahra','Qamar'),                             15.00,  72.00, 0.50),
    'Água Perfumada':     (('Mizan','Attar Real','Qamar','Nadir'),                      54.00, 168.00, 0.43),
    'Sabonete Artesanal': (('Rihan','Bayt Al Oud'),                                     18.00,  54.00, 0.40),
}

# notas olfativas — vira coluna do produto, boa para análise de mix
NOTAS = ['Oud', 'Âmbar', 'Almíscar', 'Rosa', 'Sândalo', 'Baunilha',
         'Açafrão', 'Jasmim', 'Patchouli', 'Cardamomo', 'Incenso', 'Cedro']

UNIDADES = ['UN','CX 6','CX 12','KIT 3','KIT 5','DISPLAY 24']

FORMAS_PAGAMENTO = [
    # (nome, peso, prazo_medio_dias, taxa)
    ('Boleto 28 dias',    0.30, 28, 0.000),
    ('Boleto 14 dias',    0.18, 14, 0.000),
    ('PIX',               0.22,  0, 0.000),
    ('Dinheiro',          0.08,  0, 0.000),
    ('Cartão de crédito', 0.13,  1, 0.032),
    ('Cartão de débito',  0.06,  1, 0.018),
    ('Cheque a prazo',    0.03, 35, 0.000),
]

ETAPAS_FUNIL = ['Prospecção','Qualificação','Proposta enviada','Negociação','Fechado ganho','Fechado perdido']
MOTIVOS_PERDA = ['Preço acima do concorrente','Sem verba no momento','Já compra de outro importador',
                 'Prazo de entrega','Sem contato','Fechou com concorrente',
                 'Mix de fragrâncias não atende','Pediu exclusividade de marca']
ORIGENS_OPORTUNIDADE = ['Prospecção ativa','Indicação','Inbound site','Feira de beleza','Reativação','WhatsApp','Instagram']

RESULTADO_VISITA = ['Pedido realizado','Sem pedido','Cliente ausente','Reagendada','Apenas relacionamento']

NOMES = ['Ana','Bruno','Carla','Diego','Eduarda','Felipe','Gabriela','Henrique','Isabela','João',
         'Karina','Lucas','Mariana','Nathan','Olívia','Paulo','Queila','Rafael','Sabrina','Thiago',
         'Ursula','Vinícius','Wagner','Yasmin','Zeca','Amanda','Caio','Débora','Everton','Fernanda']
SOBRENOMES = ['Silva','Santos','Oliveira','Souza','Rodrigues','Ferreira','Alves','Pereira','Lima',
              'Gomes','Costa','Ribeiro','Martins','Carvalho','Almeida','Lopes','Soares','Fernandes']

RAZAO_PREFIXO = ['Perfumaria','Farmácia','Drogaria','Boutique','Essência','Casa de Fragrâncias',
                 'Comercial','Loja','Espaço Beleza','Studio','Aroma','Bella']
RAZAO_NOME = ['Aurora','Bella Vita','Essenza','Flor de Liz','Charme','Prime','Elegance',
              'Vitória','Dourada','Encanto','Nobre','Class','Diva','Íris','Lumiar',
              'Rosa dos Ventos','Sublime','Aromas do Sul','Nova Era','Requinte','Serena']
RAZAO_SUFIXO = ['LTDA','ME','EIRELI','LTDA ME','S/A']


def dec(v):
    return Decimal(str(v)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def gerar_cnpj(rng):
    n = ''.join(str(rng.randint(0, 9)) for _ in range(14))
    return n


def formatar_cnpj(n, formato):
    if formato == 'pontuado':
        return f'{n[:2]}.{n[2:5]}.{n[5:8]}/{n[8:12]}-{n[12:]}'
    if formato == 'espaco':
        return f' {n} '
    return n


def sem_acento(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s)
                   if unicodedata.category(c) != 'Mn')


def fator_sazonal(d):
    """Perfumaria tem quatro picos: Dia das Mães, Namorados, Black Friday e Natal.
    O varejo compra ANTES da data, então o pico da distribuidora é o mês anterior."""
    m = d.month
    base = {1:0.62, 2:0.74, 3:0.88, 4:1.32,   # abril: reposição p/ Dia das Mães
            5:0.96, 6:1.24,                    # junho: Dia dos Namorados
            7:0.82, 8:0.86, 9:0.94,
            10:1.42, 11:1.28, 12:0.78}[m]      # outubro: reposição p/ Black Friday
    # varejo compra em dia útil, concentrado no começo da semana
    if d.weekday() == 0:    base *= 1.20   # segunda
    elif d.weekday() == 1:  base *= 1.12   # terça
    elif d.weekday() == 5:  base *= 0.30   # sábado
    elif d.weekday() == 6:  base *= 0.08   # domingo
    return base


def fator_sazonal_mes(d):
    """Só o efeito do mês, aplicado ao volume do pedido."""
    return {1:0.60, 2:0.72, 3:0.88, 4:1.45, 5:0.92, 6:1.30,
            7:0.80, 8:0.84, 9:0.95, 10:1.55, 11:1.30, 12:0.72}[d.month]


def fator_tendencia(d):
    """Crescimento leve ao longo dos 24 meses."""
    meses = (d.year - INICIO.year) * 12 + (d.month - INICIO.month)
    return 1.0 + meses * 0.026


def escrever(caminho, cabecalho, linhas):
    with open(caminho, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(cabecalho)
        w.writerows(linhas)
    print(f'  {os.path.basename(caminho):24} {len(linhas):>8,} linhas'.replace(',', '.'))


# ======================================================================
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--saida', default='./dados_vale_verde')
    ap.add_argument('--seed', type=int, default=42)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    os.makedirs(args.saida, exist_ok=True)
    crm = os.path.join(args.saida, 'crm'); os.makedirs(crm, exist_ok=True)
    erp = os.path.join(args.saida, 'erp'); os.makedirs(erp, exist_ok=True)

    print(f'\nGerando dataset Rota do Perfume  ·  seed={args.seed}')
    print(f'Período: {INICIO} a {FIM}\n')

    # ------------------------------------------------------------------
    # CRM · VENDEDORES
    # ------------------------------------------------------------------
    print('CRM')
    vendedores = []
    for i in range(1, N_VENDEDORES + 1):
        adm = INICIO - timedelta(days=rng.randint(30, 1500))
        # ~14% foram desligados durante o período
        desl = ''
        if rng.random() < 0.14:
            desl = (INICIO + timedelta(days=rng.randint(90, (FIM - INICIO).days - 30))).isoformat()
        cid = rng.choice(CIDADES)
        vendedores.append({
            'id': i,
            'nome': f'{rng.choice(NOMES)} {rng.choice(SOBRENOMES)}',
            'regiao': cid[0],
            'uf': cid[1],
            'admissao': adm,
            'desligamento': desl,
            'meta_mensal': rng.choice([40000, 55000, 70000, 85000, 100000]),
        })
    escrever(os.path.join(crm, 'vendedores.csv'),
             ['vendedor_id','nome','regiao','uf','data_admissao','data_desligamento','meta_mensal'],
             [[v['id'], v['nome'], v['regiao'], v['uf'], v['admissao'].isoformat(),
               v['desligamento'], v['meta_mensal']] for v in vendedores])

    # ------------------------------------------------------------------
    # CRM · CLIENTES
    # ------------------------------------------------------------------
    clientes = []
    cnpjs_base = {}
    for i in range(1, N_CLIENTES + 1):
        cid, uf, reg = rng.choice(CIDADES)
        cnpj_n = gerar_cnpj(rng)
        cnpjs_base[i] = cnpj_n
        cad = INICIO - timedelta(days=rng.randint(0, 1200))
        if rng.random() < 0.25:  # entram durante o período
            cad = INICIO + timedelta(days=rng.randint(0, (FIM - INICIO).days - 60))
        seg = rng.choice(SEGMENTOS)
        razao = f'{rng.choice(RAZAO_PREFIXO)} {rng.choice(RAZAO_NOME)} {rng.choice(RAZAO_SUFIXO)}'
        # porte determina volume de compra
        porte = rng.choices(['P','M','G'], weights=[0.55, 0.33, 0.12])[0]
        clientes.append({
            'id': i, 'cnpj': cnpj_n, 'razao': razao, 'segmento': seg,
            'cidade': cid, 'uf': uf, 'bairro': rng.choice(BAIRROS),
            'cadastro': cad, 'porte': porte,
            'ativo': rng.random() > 0.08,
        })

    linhas = []
    for c in clientes:
        # SUJEIRA 1: CNPJ em 3 formatos diferentes
        fmt = rng.choices(['puro','pontuado','espaco'], weights=[0.55, 0.38, 0.07])[0]
        # SUJEIRA 2: razão social às vezes sem acento, às vezes em caixa alta
        razao = c['razao']
        r = rng.random()
        if r < 0.08:   razao = razao.upper()
        elif r < 0.14: razao = sem_acento(razao)
        # SUJEIRA 3: data de cadastro em dois formatos
        if rng.random() < 0.12:
            dt = c['cadastro'].strftime('%d/%m/%Y')
        else:
            dt = c['cadastro'].isoformat()
        linhas.append([c['id'], formatar_cnpj(c['cnpj'], fmt), razao, c['segmento'],
                       c['cidade'], c['uf'], c['bairro'], dt,
                       'S' if c['ativo'] else 'N'])

    # SUJEIRA 4: ~40 clientes duplicados com id novo e CNPJ escrito diferente
    prox_id = N_CLIENTES + 1
    duplicados = rng.sample(clientes, 40)
    for c in duplicados:
        fmt2 = 'pontuado' if rng.random() < 0.5 else 'puro'
        linhas.append([prox_id, formatar_cnpj(c['cnpj'], fmt2), c['razao'].upper(), c['segmento'],
                       c['cidade'], c['uf'], c['bairro'], c['cadastro'].isoformat(), 'S'])
        prox_id += 1

    escrever(os.path.join(crm, 'clientes.csv'),
             ['cliente_id','cnpj','razao_social','segmento','cidade','uf','bairro',
              'data_cadastro','ativo'], linhas)

    # ------------------------------------------------------------------
    # CRM · CARTEIRA  (vínculo vendedor ↔ cliente, com troca ao longo do tempo)
    # ------------------------------------------------------------------
    carteira = []
    carteira_atual = {}
    cid_carteira = 1
    for c in clientes:
        v = rng.choice(vendedores)
        ini = max(c['cadastro'], INICIO)
        # 22% dos clientes trocam de vendedor durante o período
        if rng.random() < 0.22:
            troca = ini + timedelta(days=rng.randint(60, max(90, (FIM - ini).days - 30)))
            carteira.append([cid_carteira, c['id'], v['id'], ini.isoformat(),
                             (troca - timedelta(days=1)).isoformat()]); cid_carteira += 1
            v2 = rng.choice(vendedores)
            carteira.append([cid_carteira, c['id'], v2['id'], troca.isoformat(), '']); cid_carteira += 1
            carteira_atual[c['id']] = [(ini, troca - timedelta(days=1), v['id']),
                                       (troca, FIM, v2['id'])]
        else:
            carteira.append([cid_carteira, c['id'], v['id'], ini.isoformat(), '']); cid_carteira += 1
            carteira_atual[c['id']] = [(ini, FIM, v['id'])]
    escrever(os.path.join(crm, 'carteira.csv'),
             ['carteira_id','cliente_id','vendedor_id','data_inicio','data_fim'], carteira)

    def vendedor_do_cliente(cli_id, d):
        for ini, fim, vid in carteira_atual[cli_id]:
            if ini <= d <= fim:
                return vid
        return carteira_atual[cli_id][-1][2]

    # ------------------------------------------------------------------
    # ERP · PRODUTOS
    # ------------------------------------------------------------------
    print('\nERP')
    produtos = []
    sku_id = 1
    for cat, (marcas, pmin, pmax, margem) in CATEGORIAS.items():
        qtd = max(8, int(N_PRODUTOS * (len(marcas) / 42)))
        for _ in range(qtd):
            marca = rng.choice(marcas)
            preco = dec(rng.uniform(pmin, pmax))
            custo = dec(float(preco) * (1 - margem - rng.uniform(-0.04, 0.04)))
            # 9% descontinuados
            ativo = rng.random() > 0.09
            nota = rng.choice(NOTAS)
            unid = rng.choice(UNIDADES)
            # 18% dos produtos são lançamentos dentro do período — geram pico
            lanc = ''
            if rng.random() < 0.18:
                lanc = (INICIO + timedelta(days=rng.randint(60, (FIM - INICIO).days - 90))).isoformat()
            produtos.append({
                'sku': f'SKU{sku_id:05d}',
                'desc': f'{marca} {nota} {cat} {unid}',
                'cat': cat, 'marca': marca, 'nota': nota, 'preco': preco, 'custo': custo,
                'unidade': unid, 'ativo': ativo, 'lancamento': lanc,
            })
            sku_id += 1
    escrever(os.path.join(erp, 'produtos.csv'),
             ['sku','descricao','categoria','marca','nota_olfativa','preco_tabela',
              'custo_unitario','unidade','ativo','data_lancamento'],
             [[p['sku'], p['desc'], p['cat'], p['marca'], p['nota'], p['preco'], p['custo'],
               p['unidade'], 'S' if p['ativo'] else 'N', p['lancamento']] for p in produtos])

    prod_ativos = [p for p in produtos if p['ativo']]
    prod_inativos = [p for p in produtos if not p['ativo']]
    for p in produtos:
        p['_lanc_dt'] = date.fromisoformat(p['lancamento']) if p['lancamento'] else None
    prod_lancados = [p for p in prod_ativos if p['_lanc_dt']]

    # ------------------------------------------------------------------
    # ERP · PEDIDOS + ITENS + PAGAMENTOS
    # ------------------------------------------------------------------
    pedidos, itens, pagamentos = [], [], []
    ped_id, item_id, pag_id = 1, 1, 1

    # frequência de compra por porte (dias entre pedidos)
    freq = {'P': (55, 130), 'M': (32, 70), 'G': (16, 38)}
    itens_por_pedido = {'P': (2, 6), 'M': (4, 10), 'G': (6, 16)}

    # ~11% dos clientes viram churn: param de comprar em algum momento
    churn = {}
    for c in clientes:
        if rng.random() < 0.11:
            churn[c['id']] = INICIO + timedelta(days=rng.randint(120, (FIM - INICIO).days - 40))

    pesos_pag = [f[1] for f in FORMAS_PAGAMENTO]

    for c in clientes:
        d = max(c['cadastro'], INICIO) + timedelta(days=rng.randint(0, 20))
        lo, hi = freq[c['porte']]
        while d <= FIM:
            if c['id'] in churn and d > churn[c['id']]:
                break
            if not c['ativo'] and rng.random() < 0.6:
                break
            saz = fator_sazonal(d) * fator_tendencia(d)
            if rng.random() > min(0.97, saz * 0.72):
                d += timedelta(days=rng.randint(2, 6))
                continue

            vend = vendedor_do_cliente(c['id'], d)
            canal = rng.choices(['Visita','Telefone','App','WhatsApp'],
                                weights=[0.44, 0.19, 0.23, 0.14])[0]
            # 3,5% cancelados
            cancelado = rng.random() < 0.035
            status = 'Cancelado' if cancelado else rng.choices(
                ['Faturado','Entregue','Em separação'], weights=[0.34, 0.62, 0.04])[0]

            n_it = rng.randint(*itens_por_pedido[c['porte']])
            escolha = list(prod_ativos)
            # lançamento puxa venda nos 4 meses seguintes: entra mais vezes no sorteio
            for p in prod_lancados:
                if p['_lanc_dt'] and 0 <= (d - p['_lanc_dt']).days <= 120:
                    escolha.extend([p] * 5)
            # SUJEIRA 5: produto descontinuado ainda aparece em venda
            if rng.random() < 0.06 and prod_inativos:
                escolha = escolha + rng.sample(prod_inativos, min(2, len(prod_inativos)))
            skus, vistos = [], set()
            tentativas = 0
            while len(skus) < n_it and tentativas < n_it * 12:
                p = rng.choice(escolha)
                if p['sku'] not in vistos:
                    vistos.add(p['sku']); skus.append(p)
                tentativas += 1

            total = Decimal('0.00')
            linhas_item = []
            for p in skus:
                qtd = rng.choices([1,2,3,4,6,8,12],
                                  weights=[.28,.24,.17,.12,.10,.06,.03])[0]
                if c['porte'] == 'G': qtd *= rng.randint(1, 2)
                # sazonalidade também no volume, não só na frequência
                qtd = max(1, int(round(qtd * fator_sazonal_mes(d))))
                desc_pct = rng.choices([0, 0.03, 0.05, 0.08, 0.12, 0.18],
                                       weights=[.42,.18,.15,.12,.09,.04])[0]
                praticado = dec(float(p['preco']) * (1 - desc_pct))
                # SUJEIRA 6: devolução entra como quantidade negativa
                if rng.random() < 0.012:
                    qtd = -abs(qtd)
                bruto = dec(float(praticado) * qtd)
                total += bruto
                linhas_item.append([item_id, ped_id, p['sku'], qtd, praticado,
                                    dec(desc_pct * 100), bruto])
                item_id += 1

            # SUJEIRA 7: pedido cancelado fica com valor zerado, sem flag óbvia
            valor_pedido = Decimal('0.00') if cancelado else total

            # SUJEIRA 8: 12% das datas em formato brasileiro
            if rng.random() < 0.12:
                d_str = d.strftime('%d/%m/%Y')
            else:
                d_str = d.isoformat()

            pedidos.append([ped_id, c['id'], vend, d_str, canal, status, valor_pedido])

            # ---- pagamento ----
            if not cancelado:
                forma_idx = rng.choices(range(len(FORMAS_PAGAMENTO)), weights=pesos_pag)[0]
                nome_f, _, prazo, taxa = FORMAS_PAGAMENTO[forma_idx]
                parcelas = 1
                if nome_f == 'Cartão de crédito':
                    parcelas = rng.choices([1,2,3,4,6], weights=[.5,.2,.15,.1,.05])[0]
                venc = d + timedelta(days=prazo)
                # status de recebimento
                if venc > FIM:
                    st_pag = 'Em aberto'; d_pag = ''
                else:
                    r = rng.random()
                    if r < 0.86:
                        st_pag = 'Pago'
                        atraso = rng.choices([0, 1, 3, 7, 15], weights=[.62,.16,.12,.07,.03])[0]
                        d_pag = (venc + timedelta(days=atraso)).isoformat()
                    elif r < 0.95:
                        st_pag = 'Pago com atraso'
                        d_pag = (venc + timedelta(days=rng.randint(16, 60))).isoformat()
                    else:
                        st_pag = 'Inadimplente'; d_pag = ''
                liquido = dec(float(valor_pedido) * (1 - taxa))
                pagamentos.append([pag_id, ped_id, nome_f, parcelas, valor_pedido,
                                   dec(taxa * 100), liquido, venc.isoformat(), d_pag, st_pag])
                pag_id += 1

            itens.extend(linhas_item)
            ped_id += 1
            d += timedelta(days=rng.randint(lo, hi))

    escrever(os.path.join(erp, 'pedidos.csv'),
             ['pedido_id','cliente_id','vendedor_id','data_pedido','canal','status','valor_total'],
             pedidos)
    escrever(os.path.join(erp, 'itens_pedido.csv'),
             ['item_id','pedido_id','sku','quantidade','preco_praticado','desconto_pct','valor_bruto'],
             itens)
    escrever(os.path.join(erp, 'pagamentos.csv'),
             ['pagamento_id','pedido_id','forma_pagamento','parcelas','valor','taxa_pct',
              'valor_liquido','data_vencimento','data_pagamento','status_pagamento'],
             pagamentos)

    # ------------------------------------------------------------------
    # ERP · ESTOQUE (snapshot semanal)
    # ------------------------------------------------------------------
    estoque = []
    d = INICIO
    while d <= FIM:
        for p in rng.sample(produtos, min(80, len(produtos))):
            saldo = rng.randint(0, 800)
            # ruptura: 7% dos snapshots com saldo zero
            if rng.random() < 0.11: saldo = 0
            estoque.append([d.isoformat(), p['sku'], saldo,
                            'S' if saldo == 0 else 'N'])
        d += timedelta(days=7)
    escrever(os.path.join(erp, 'estoque.csv'),
             ['data_snapshot','sku','saldo','ruptura'], estoque)

    # ------------------------------------------------------------------
    # CRM · OPORTUNIDADES (funil comercial)
    # ------------------------------------------------------------------
    print('\nCRM (funil)')
    oportunidades = []
    op_id = 1
    for c in clientes:
        n_op = rng.choices([0,1,2,3,4,6], weights=[.18,.27,.23,.16,.10,.06])[0]
        for _ in range(n_op):
            abertura = max(c['cadastro'], INICIO) + timedelta(
                days=rng.randint(0, max(1, (FIM - max(c['cadastro'], INICIO)).days)))
            if abertura > FIM: continue
            vend = vendedor_do_cliente(c['id'], abertura)
            valor = dec(rng.uniform(2500, 95000) * (1.8 if c['porte'] == 'G' else 1.0))
            etapa = rng.choices(ETAPAS_FUNIL, weights=[.14,.15,.17,.13,.27,.14])[0]
            fechada = etapa.startswith('Fechado')
            ciclo = rng.randint(3, 75)
            d_fech = (abertura + timedelta(days=ciclo)) if fechada else None
            if d_fech and d_fech > FIM:
                d_fech = None; etapa = 'Negociação'; fechada = False
            prob = {'Prospecção':10,'Qualificação':25,'Proposta enviada':50,
                    'Negociação':75,'Fechado ganho':100,'Fechado perdido':0}[etapa]
            motivo = rng.choice(MOTIVOS_PERDA) if etapa == 'Fechado perdido' else ''
            oportunidades.append([
                op_id, c['id'], vend, rng.choice(ORIGENS_OPORTUNIDADE),
                abertura.isoformat(), etapa, prob, valor,
                d_fech.isoformat() if d_fech else '',
                (d_fech - abertura).days if d_fech else '', motivo,
            ])
            op_id += 1
    escrever(os.path.join(crm, 'oportunidades.csv'),
             ['oportunidade_id','cliente_id','vendedor_id','origem','data_abertura','etapa',
              'probabilidade_pct','valor_estimado','data_fechamento','ciclo_dias','motivo_perda'],
             oportunidades)

    # ------------------------------------------------------------------
    # CRM · VISITAS
    # ------------------------------------------------------------------
    visitas = []
    vis_id = 1
    for c in clientes:
        d = max(c['cadastro'], INICIO)
        while d <= FIM:
            d += timedelta(days=rng.randint(16, 55))
            if d > FIM: break
            if d.weekday() >= 5: continue
            vend = vendedor_do_cliente(c['id'], d)
            res = rng.choices(RESULTADO_VISITA, weights=[.46,.24,.13,.09,.08])[0]
            dur = rng.randint(10, 90)
            visitas.append([vis_id, c['id'], vend, d.isoformat(), res, dur])
            vis_id += 1
    escrever(os.path.join(crm, 'visitas.csv'),
             ['visita_id','cliente_id','vendedor_id','data_visita','resultado','duracao_min'],
             visitas)

    # ------------------------------------------------------------------
    print(f'\nPronto. Arquivos em: {os.path.abspath(args.saida)}')
    print('  erp/  produtos, pedidos, itens_pedido, pagamentos, estoque')
    print('  crm/  clientes, vendedores, carteira, oportunidades, visitas')
    print("""
SUJEIRA PROPOSITAL (para a noite 2):
  1. CNPJ em 3 formatos: puro, pontuado e com espaço em volta
  2. Razão social às vezes em CAIXA ALTA, às vezes sem acento
  3. Data de cadastro em ISO e em dd/mm/aaaa misturadas
  4. ~40 clientes duplicados com id novo e CNPJ escrito diferente
  5. SKU descontinuado ainda aparecendo em pedido
  6. Devolução gravada como quantidade negativa
  7. Pedido cancelado com valor_total zerado, sem flag óbvia no item
  8. ~12% das datas de pedido em formato brasileiro
  9. Vendedor desligado com carteira ainda vinculada
 10. Ruptura de estoque (saldo zero) em ~11% dos snapshots
""")

if __name__ == '__main__':
    main()
