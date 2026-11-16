---
version: "alpha"
name: "Design Gráfico Suíço"
description: "Design Gráfico Suíço — design geral com design suíço, estilo internacional e visual limpo. Modelo e prompt prontos para IA."
colors:
  primary: "#7e0606"
  secondary: "#1A1A1A"
  tertiary: "#FFFFFF"
  neutral: "#A9B2B1"
  surface: "#0033A0"
  accent: "#F2F2F2"
typography:
  h1:
    fontFamily: Helvetica Neue
    fontSize: 2.5rem
    fontWeight: 700
  body-md:
    fontFamily: Helvetica Neue
    fontSize: 1rem
    fontWeight: 400
spacing:
  sm: 20.0px
  md: 40.0px
  lg: 80.0px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.neutral}"
    padding: 12px
---

## Visão geral

Design Gráfico Suíço — design geral com design suíço, estilo internacional e visual limpo. Modelo e prompt prontos para IA. O estilo de Design Gráfico Suíço representa uma tendência moderna em design de UI/UX para a Web, com foco em design geral.

- Densidade: 3/10 — arejado
- Variação: 7/10 — dinâmico
- Movimento: 4/10 — sutil

- **Estilo:** limpo, estruturado e tipográfico
- **Palavras-chave:** design suíço, estilo internacional, limpo, estruturado, tipográfico, grade, minimalista, objetivo, funcional, assimétrico
- **Época:** meados do século XX, estilo tipográfico internacional
- **Claro/escuro:** ✓ claro / ✗ escuro

## Cores

- **Vermelho de destaque** #fd0c0c — estados de erro, ações destrutivas, Treinamentos vencidos
- **Preto** #1A1A1A — superfície escura e fundo principal
- **Branco** #FFFFFF — superfície clara e fundos de cartões
- **Cinza frio** #A9B2B1 — texto secundário, bordas e elementos discretos
- **Azul profundo** #0033A0 — destaque secundário
- **Cinza claro** #F2F2F2 — texto secundário, bordas e elementos discretos
-**Laranja** #ff7300 - treinamentos proximos do vencimento 
-**Verde** #209620 - treinamentos validos, status positivos

## Tipografia

- **Exibição / destaque:** Helvetica Neue — peso 700, espaçamento entre letras compacto, usada para dar impacto aos títulos
- **Texto corrido:** Helvetica Neue — peso 400, 16 px/altura de linha 1,6, máximo de 72 caracteres por linha
- **Rótulos da interface / legendas:** Helvetica Neue — 0,875 rem, peso 500, leve espaçamento entre letras
- **Monoespaçada:** JetBrains Mono — usada em código, metadados e valores técnicos

Escala:
- Destaque: clamp(2.5rem, 5vw, 4rem)
- H1: 2.25rem
- H2: 1.5rem
- Texto corrido: 1rem / 1.6
- Pequeno: 0.875rem

## Layout

- **Grade:** CSS Grid como estrutura principal. Largura máxima: 1280 px, centralizada, com preenchimento lateral de 1,5 rem.
- **Ritmo de espaçamento:** equilibrado. Unidade base: 0,5 rem (8 px).
- **Espaçamento vertical entre seções:** clamp(4rem, 8vw, 8rem).
- **Layout de destaque:** composição assimétrica.
- **Seções de recursos:** grade assimétrica com cartões de tamanhos variados. Não usar três colunas iguais.
- **Adaptação para dispositivos móveis:** todos os layouts com várias colunas se reorganizam em uma coluna abaixo de 768 px. Evitar rolagem horizontal.
- **Convenção de z-index:** base (0) / navegação fixa (100) / sobreposição (200) / modal (300) / notificação (500).

## Elevação e profundidade

Sistema de grade forte, tipografia sem serifa (Helvetica), layout assimétrico, linhas limpas, foco no espaço negativo, fotografia objetiva, sem ornamentos, texto alinhado à esquerda com margem direita irregular.

- **Animação:** curvas de desaceleração, duração de 200–300 ms. Suave e previsível.
- **Animações de entrada:** esmaecer + translação no eixo Y (16 px → 0) durante 420 ms, com desaceleração. Em listas, aplicar em cascata, com intervalo de 80 ms entre itens.
- **Estados ao passar o cursor:** mudança sutil de cor + ajuste de sombra durante 200 ms.
- **Transições de página:** apenas esmaecimento (200 ms).
- **Desempenho:** animar somente transform e opacidade. Não animar propriedades que acionem o recálculo do layout.

## Formas

Raio de canto base: 8 px. Consulte os tokens de borda arredondada no front matter para ver a escala completa.

## Componentes

- **Botão primário:** formato levemente arredondado (0,5 rem). Preenchimento com a cor de destaque. Ao passar o cursor: escurecer 8% + sombra sutil de elevação. Ativo: deslocamento tátil de -1 px. Peso da fonte 600. Sem brilho externo.
- **Botão secundário / fantasma:** variante com contorno. Borda de 1,5 px em cor discreta. Texto na cor primária. Ao passar o cursor: preenchimento de fundo sutil.
- **Cartões:** cantos levemente arredondados (0,5 rem). Fundo de superfície. Sombra sutil (0 2px 12px rgba(0,0,0,0.06)). Contorno de 1 px.
- **Campos de entrada:** rótulo acima do campo. Contorno de 1 px. Ao receber foco: anel de 2 px na cor de destaque, com deslocamento de 2 px. Texto de erro abaixo, em vermelho semântico. Não usar rótulos flutuantes.
- **Navegação:** fundo na cor da superfície principal. Item ativo: indicador na cor de destaque. Peso da fonte 500 quando ativo.
- **Esqueletos de carregamento:** animação de brilho que corresponda às dimensões do componente. Não usar indicadores circulares giratórios.
- **Estados vazios:** composição baseada em ícone, com texto descritivo e botão de ação.

## Recomendações e restrições

- Não usar emojis na interface — usar apenas o sistema de ícones (Lucide, Heroicons).
- Não usar gradientes decorativos — somente cores chapadas.
- Não usar sombras mais fortes que 0 2px 8px rgba(0,0,0,0.08).
- Não usar preto puro (#000000) — preferir tons de preto suave ou carvão.
- Não usar cores de destaque excessivamente saturadas (limite de saturação: 80%).
- Não usar layouts de recursos com três colunas de mesma largura — preferir composição em zigue-zague ou grade assimétrica.
- Não usar `h-screen` — usar `min-h-[100dvh]`.
- Evitar clichês de texto gerado por IA: “Eleve”, “Sem atritos”, “Liberte”, “Nova geração”.
- Não usar links quebrados para imagens externas — usar picsum.photos ou SVG embutido.
- Não usar texto genérico de preenchimento (lorem ipsum) em demonstrações.

- Usar um sistema de grade forte.
- Usar tipografia sem serifa.
- Usar layout assimétrico.
- Usar linhas limpas.
- Priorizar o espaço negativo.
- Usar fotografia objetiva.

## Casos de uso

Páginas de apresentação e SaaS.
