# Diagrama entidade-relacionamento

`der.png` é a imagem do DER utilizada no relatório. `OMTG-infraestrutura_bh_omtg_designer.xml` é o arquivo-fonte editável.

A relação entre `equipamentos_saude` e `bairros` utiliza a chave estrangeira `codigo_bairro`, que referencia `bairros.codigo`. A relação entre `vias` e `bairros` é espacial, muitos-para-muitos, consultada por meio da função `ST_Intersects`.
