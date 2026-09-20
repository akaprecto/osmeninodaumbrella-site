# Fontes do site

O site usa `aerosoldier/Aerosoldier_PERSONAL_USE_ONLY.otf` nos títulos.
A comparação visual no Chrome confirmou o desenho da imagem de referência,
incluindo a renderização de É e Ã. Os títulos voltaram a ter acentuação.

Nos demais textos, a pilha começa em `-apple-system` e `BlinkMacSystemFont`
para usar a fonte nativa da Apple em iPhone, iPad e Mac. Em outros sistemas,
usa Helvetica Neue, Segoe UI ou Arial conforme a disponibilidade.

Uma entrada no mapa de caracteres de uma fonte não garante que o desenho
correspondente esteja visível: a Spray Letters tinha entradas para acentos,
mas a comparação visual mostrou caracteres vazios. Por isso ela foi substituída.

## Cópia corrigida da Bored Schoolboy (não utilizada atualmente)

`BOREDSB-web.ttf` é uma cópia corrigida. O original `BOREDSB.TTF` foi preservado.

O original era rejeitado pelo Chrome com `OTS parsing error: cmap: Bad cmap subtable`.
A subtabela Mac Roman de formato 0 declarava comprimento zero, em vez de 262 bytes.
A cópia corrige esse campo e recalcula os checksums, sem modificar os desenhos das letras.
O script `../tools/repair-font.ps1` reproduz a correção.

Validação: o Chrome carregou a cópia com `document.fonts.load`, retornando
`status: loaded`, sem erros de decodificação.

Limitação: a fonte contém apenas A–Z e a–z. Acentos, números e pontuação ainda
usam a fonte substituta do navegador. A correção estrutural não adiciona caracteres.
