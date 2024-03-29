## ----setup, include=FALSE---------------------------------------------------------------------------------------------------------------------
knitr::opts_chunk$set(echo = TRUE)


## ----echo=TRUE--------------------------------------------------------------------------------------------------------------------------------
pacman::p_load(rlang, 
               data.table, 
               ggplot2,
               ggfortify, 
               stringr, 
               dplyr, 
               statmod, 
               tibble,
               ggpubr, 
               sjPlot, 
               tidyr,
               tidytext, 
               OmicsAnalyst,
               tidytable, 
               gridExtra,
               openxlsx)


## ---------------------------------------------------------------------------------------------------------------------------------------------
impCG = fread('DGEresults/Limma_results_table_CG.csv')

impPHY = fread('DGEresults/Limma_results_table_PHY.csv')

impNEM = fread('DGEresults/Limma_results_table_NEM.csv')

impLength = fread('DGEresults/Limma_results_table_Length.csv')


## ---------------------------------------------------------------------------------------------------------------------------------------------
subcell_CG = impCG %>% 
  distinct(GeneID, logFC, Subcell_loc) %>% 
  group_by(Subcell_loc) %>% 
  mutate(Term_logFC = mean(logFC)) 

p1 = ggplot(subcell_CG, aes(reorder(Subcell_loc, logFC), logFC, fill = Term_logFC))+
  geom_boxplot()+
  theme(axis.text.x = element_text(angle = 30, size = 10))+
  xlab(NULL)+
  ggtitle('Crown Gall Subcellular Localization')+
  geom_hline(yintercept = 0, linetype = 'dashed', color = 'red')+
  scale_fill_gradient2(low = 'blue', high = 'red')+
  theme(legend.position = 'bottom', legend.margin = margin(t = -50), plot.margin = margin(0.5, 2, 0.5, 0.5, "cm"))

p1

save_plot('Subcell_results//Subcell_boxplot_CG.png', p1)


## ---------------------------------------------------------------------------------------------------------------------------------------------
test = impCG %>%
  mutate(sign = ifelse(logFC >= 0, '+', '-')) %>%
  distinct(GeneID, Subcell_loc, sign) %>% 
  # group_by(Subcell_loc) %>% 
  count(Subcell_loc, sign) %>% 
  pivot_wider(names_from = sign, values_from = n) %>% 
  replace(is.na(.), 0) %>% 
  ungroup() %>% 
  mutate(expected = (`-`/sum(`-`, na.rm = T)*sum(`+`, na.rm = T)),
         sum_neg = sum(`-`),
         sum_pos = sum(`+`),
         neg_not_in_SL = sum_neg - `-`,
         pos_not_in_SL = sum_pos - `+`,
         `+mod` =  ifelse(`+` == 0, min(expected)-0.1, `+`),
         num_genes = `+`+`-`,
         fold_enrichment = log2(`+mod`/expected)
         ) %>% 
  rowwise() %>%
  mutate(
  fisher.p = fisher.test(x = matrix(c(`+`, `-`, pos_not_in_SL, neg_not_in_SL), nrow = 2))[[1]],
  fisher.odds = fisher.test(x = matrix(c(`+`, `-`, pos_not_in_SL, neg_not_in_SL), nrow = 2))[[3]][1]
  ) %>% 
  ungroup() %>% 
  mutate(FDR = p.adjust(fisher.p, method = 'BH'))  %>% 
  left_join(subcell_CG, by = 'Subcell_loc')

View(test %>% select(!c(GeneID, logFC)) %>% distinct())

plot_dat = test %>% 
  select(!c(GeneID, logFC)) %>% 
  distinct()

results = test %>% 
  left_join(impCG %>% select(GeneID, name)) %>% 
  rename_with(~ paste('Subcell_', .x, sep = ''))

fwrite(results, 'Subcell_results/Subcell_Results_Table_CG.csv')



## ---------------------------------------------------------------------------------------------------------------------------------------------
ggplot(filter(plot_dat, FDR <= 0.05), aes(reorder(Subcell_loc, fold_enrichment), fold_enrichment, fill = fold_enrichment))+
  geom_col(color = 'black')+
  theme(axis.text.x = element_text(angle = 30, size = 10))+
  # geom_label(aes(label = INF))+
  xlab(NULL)+
  # expand_limits(y = c(-2.5, 10))+
  ggtitle('Subcellular Localization Fisher\'s Exact Test CG')+
  geom_hline(yintercept = 0, linetype = 'dashed', color = 'red')+
  scale_fill_gradient2(low = 'blue', high = 'red')


## ----fig.height=6, fig.width=9, warning=FALSE, message=FALSE----------------------------------------------------------------------------------
CG = ggplot(plot_dat, aes(x = Term_logFC, y = log2(FDR)*-1, color = fold_enrichment))+
  geom_point(aes(size = num_genes, color = fold_enrichment))+
  geom_point(aes(size = num_genes), shape = 1, stroke = 0.25, color = 'black')+
  ggrepel::geom_label_repel(data = filter(plot_dat, FDR <= 0.05), aes(label = Subcell_loc),
                            size = 4,
                            color = 'black', 
                            box.padding = 0.4,
                            label.padding = 0.1,
                            max.overlaps = Inf)+
  labs(title = 'Subcellular Localization Fisher\'s Exact Test CG',
       x = 'Mean log2 Expression Fold Change',
       color = 'Log2 \nFold Enrichment',
       size = 'Number of Genes')+
  theme_grey(base_size = 16)+
  theme(plot.title = element_text(hjust = 0.5))+
  geom_hline(yintercept = log2(0.05)*-1, linetype = 'dashed', color = 'red')+
  geom_text(aes(min(Term_logFC), log2(0.05)*-1),
            label = 'FDR 0.05',
            vjust = 1.5,
            hjust = 2, 
            color = 'black',
            size = 3)+
  geom_vline(xintercept = 0, linetype = 'dashed', color = 'black')+
  geom_hline(yintercept = 0, linetype = 'dashed', color = 'black')+
  lims(x = c(sqrt(max(plot_dat$Term_logFC^2))*-1, sqrt(max(plot_dat$Term_logFC^2))),
       y = c(-1, max(log2(plot_dat$FDR)*-1)))+
  scale_color_gradient2(low = 'blue', high = 'red')+
  scale_size_continuous(breaks = c(10, 30, 100, 200, 1200),
                        limits = c(0, 1200))

CG

save_plot('Subcell_results/Subcell_CG.png', width = 26, height = 15)


## ---------------------------------------------------------------------------------------------------------------------------------------------
subcell_PHY = impPHY %>% 
  distinct(GeneID, logFC, Subcell_loc) %>% 
  group_by(Subcell_loc) %>% 
  mutate(Term_logFC = mean(logFC)) 

p1 = ggplot(subcell_PHY, aes(reorder(Subcell_loc, logFC), logFC, fill = Term_logFC))+
  geom_boxplot()+
  theme(axis.text.x = element_text(angle = 30, size = 10))+
  xlab(NULL)+
  ggtitle('Crown Gall Subcellular Localization')+
  geom_hline(yintercept = 0, linetype = 'dashed', color = 'red')+
  scale_fill_gradient2(low = 'blue', high = 'red')+
  theme(legend.position = 'bottom', legend.margin = margin(t = -50), plot.margin = margin(0.5, 2, 0.5, 0.5, "cm"))

p1

save_plot('Subcell_results//Subcell_boxplot_PHY.png', p1)


## ---------------------------------------------------------------------------------------------------------------------------------------------
test = impPHY %>%
  mutate(sign = ifelse(logFC >= 0, '+', '-')) %>%
  distinct(GeneID, Subcell_loc, sign) %>% 
  # group_by(Subcell_loc) %>% 
  count(Subcell_loc, sign) %>% 
  pivot_wider(names_from = sign, values_from = n) %>% 
  replace(is.na(.), 0) %>% 
  ungroup() %>% 
  mutate(expected = (`-`/sum(`-`, na.rm = T)*sum(`+`, na.rm = T)),
         sum_neg = sum(`-`),
         sum_pos = sum(`+`),
         neg_not_in_SL = sum_neg - `-`,
         pos_not_in_SL = sum_pos - `+`,
         `+mod` =  ifelse(`+` == 0, min(expected)-0.1, `+`),
         num_genes = `+`+`-`,
         fold_enrichment = log2(`+mod`/expected)
         ) %>% 
  rowwise() %>%
  mutate(
  fisher.p = fisher.test(x = matrix(c(`+`, `-`, pos_not_in_SL, neg_not_in_SL), nrow = 2))[[1]],
  fisher.odds = fisher.test(x = matrix(c(`+`, `-`, pos_not_in_SL, neg_not_in_SL), nrow = 2))[[3]][1]
  ) %>% 
  ungroup() %>% 
  mutate(FDR = p.adjust(fisher.p, method = 'BH'))  %>% 
  left_join(subcell_CG, by = 'Subcell_loc')

View(test %>% select(!c(GeneID, logFC)) %>% distinct())

plot_dat = test %>% 
  select(!c(GeneID, logFC)) %>% 
  distinct()

results = test %>% 
  left_join(impCG %>% select(GeneID, name)) %>% 
  rename_with(~ paste('Subcell_', .x, sep = ''))

fwrite(results, 'Subcell_results/Subcell_Results_Table_PHY.csv')



## ---------------------------------------------------------------------------------------------------------------------------------------------
ggplot(filter(plot_dat, FDR <= 0.05), aes(reorder(Subcell_loc, fold_enrichment), fold_enrichment, fill = fold_enrichment))+
  geom_col(color = 'black')+
  theme(axis.text.x = element_text(angle = 30, size = 10))+
  # geom_label(aes(label = INF))+
  xlab(NULL)+
  # expand_limits(y = c(-2.5, 10))+
  ggtitle('Subcellular Localization Fisher\'s Exact Test PHY')+
  geom_hline(yintercept = 0, linetype = 'dashed', color = 'red')+
  scale_fill_gradient2(low = 'blue', high = 'red')


## ----fig.height=6, fig.width=9, warning=FALSE, message=FALSE----------------------------------------------------------------------------------
PHY = ggplot(plot_dat, aes(x = Term_logFC, y = log2(FDR)*-1, color = fold_enrichment))+
  geom_point(aes(size = num_genes, color = fold_enrichment))+
  geom_point(aes(size = num_genes), shape = 1, stroke = 0.25, color = 'black')+
  ggrepel::geom_label_repel(data = filter(plot_dat, FDR <= 0.05), aes(label = Subcell_loc),
                            size = 4,
                            color = 'black', 
                            box.padding = 0.4,
                            label.padding = 0.1,
                            max.overlaps = Inf)+
  labs(title = 'Subcellular Localization Fisher\'s Exact Test PHY',
       x = 'Mean log2 Expression Fold Change',
       color = 'Log2 \nFold Enrichment',
       size = 'Number of Genes')+
  theme_grey(base_size = 16)+
  theme(plot.title = element_text(hjust = 0.5))+
  geom_hline(yintercept = log2(0.05)*-1, linetype = 'dashed', color = 'red')+
  geom_text(aes(min(Term_logFC), log2(0.05)*-1),
            label = 'FDR 0.05',
            vjust = 1.5,
            # hjust = 2, 
            color = 'black',
            size = 3)+
  geom_vline(xintercept = 0, linetype = 'dashed', color = 'black')+
  geom_hline(yintercept = 0, linetype = 'dashed', color = 'black')+
  lims(x = c(sqrt(max(plot_dat$Term_logFC^2))*-1, sqrt(max(plot_dat$Term_logFC^2))),
       y = c(-1, max(log2(plot_dat$FDR)*-1)))+
  scale_color_gradient2(low = 'blue', high = 'red')+
  scale_size_continuous(breaks = c(10, 30, 100, 200, 1200),
                        limits = c(0, 1200))

PHY

save_plot('Subcell_results/Subcell_PHY.png', width = 26, height = 15)


## ---------------------------------------------------------------------------------------------------------------------------------------------
subcell_NEM = impNEM %>% 
  distinct(GeneID, logFC, Subcell_loc) %>% 
  group_by(Subcell_loc) %>% 
  mutate(Term_logFC = mean(logFC)) 

p1 = ggplot(subcell_NEM, aes(reorder(Subcell_loc, logFC), logFC, fill = Term_logFC))+
  geom_boxplot()+
  theme(axis.text.x = element_text(angle = 30, size = 10))+
  xlab(NULL)+
  ggtitle('Crown Gall Subcellular Localization')+
  geom_hline(yintercept = 0, linetype = 'dashed', color = 'red')+
  scale_fill_gradient2(low = 'blue', high = 'red')+
  theme(legend.position = 'bottom', legend.margin = margin(t = -50), plot.margin = margin(0.5, 2, 0.5, 0.5, "cm"))

p1

save_plot('Subcell_results//Subcell_boxplot_NEM.png', p1)


## ---------------------------------------------------------------------------------------------------------------------------------------------
test = impNEM %>%
  mutate(sign = ifelse(logFC >= 0, '+', '-')) %>%
  distinct(GeneID, Subcell_loc, sign) %>% 
  # group_by(Subcell_loc) %>% 
  count(Subcell_loc, sign) %>% 
  pivot_wider(names_from = sign, values_from = n) %>% 
  replace(is.na(.), 0) %>% 
  ungroup() %>% 
  mutate(expected = (`-`/sum(`-`, na.rm = T)*sum(`+`, na.rm = T)),
         sum_neg = sum(`-`),
         sum_pos = sum(`+`),
         neg_not_in_SL = sum_neg - `-`,
         pos_not_in_SL = sum_pos - `+`,
         `+mod` =  ifelse(`+` == 0, min(expected)-0.1, `+`),
         num_genes = `+`+`-`,
         fold_enrichment = log2(`+mod`/expected)
         ) %>% 
  rowwise() %>%
  mutate(
  fisher.p = fisher.test(x = matrix(c(`+`, `-`, pos_not_in_SL, neg_not_in_SL), nrow = 2))[[1]],
  fisher.odds = fisher.test(x = matrix(c(`+`, `-`, pos_not_in_SL, neg_not_in_SL), nrow = 2))[[3]][1]
  ) %>% 
  ungroup() %>% 
  mutate(FDR = p.adjust(fisher.p, method = 'BH'))  %>% 
  left_join(subcell_CG, by = 'Subcell_loc')

View(test %>% select(!c(GeneID, logFC)) %>% distinct())

plot_dat = test %>% 
  select(!c(GeneID, logFC)) %>% 
  distinct()

results = test %>% 
  left_join(impCG %>% select(GeneID, name)) %>% 
  rename_with(~ paste('Subcell_', .x, sep = ''))

fwrite(results, 'Subcell_results/Subcell_Results_Table_NEM.csv')



## ---------------------------------------------------------------------------------------------------------------------------------------------
ggplot(filter(plot_dat, FDR <= 0.05), aes(reorder(Subcell_loc, fold_enrichment), fold_enrichment, fill = fold_enrichment))+
  geom_col(color = 'black')+
  theme(axis.text.x = element_text(angle = 30, size = 10))+
  # geom_label(aes(label = INF))+
  xlab(NULL)+
  # expand_limits(y = c(-2.5, 10))+
  ggtitle('Subcellular Localization Fisher\'s Exact Test NEM')+
  geom_hline(yintercept = 0, linetype = 'dashed', color = 'red')+
  scale_fill_gradient2(low = 'blue', high = 'red')


## ----fig.height=6, fig.width=9, warning=FALSE, message=FALSE----------------------------------------------------------------------------------
NEM = ggplot(plot_dat, aes(x = Term_logFC, y = log2(FDR)*-1, color = fold_enrichment))+
  geom_point(aes(size = num_genes, color = fold_enrichment))+
  geom_point(aes(size = num_genes), shape = 1, stroke = 0.25, color = 'black')+
  ggrepel::geom_label_repel(data = filter(plot_dat, FDR <= 0.05), aes(label = Subcell_loc),
                            size = 4,
                            color = 'black', 
                            box.padding = 0.4,
                            label.padding = 0.1,
                            max.overlaps = Inf)+
  labs(title = 'Subcellular Localization Fisher\'s Exact Test NEM',
       x = 'Mean log2 Expression Fold Change',
       color = 'Log2 \nFold Enrichment',
       size = 'Number of Genes')+
  theme_grey(base_size = 16)+
  theme(plot.title = element_text(hjust = 0.5))+
  geom_hline(yintercept = log2(0.05)*-1, linetype = 'dashed', color = 'red')+
  geom_text(aes(min(Term_logFC), log2(0.05)*-1),
            label = 'FDR 0.05',
            vjust = 1.5,
            # hjust = 2, 
            color = 'black',
            size = 3)+
  geom_vline(xintercept = 0, linetype = 'dashed', color = 'black')+
  geom_hline(yintercept = 0, linetype = 'dashed', color = 'black')+
  lims(x = c(sqrt(max(plot_dat$Term_logFC^2))*-1, sqrt(max(plot_dat$Term_logFC^2))),
       y = c(-1, max(log2(plot_dat$FDR)*-1)))+
  scale_color_gradient2(low = 'blue', high = 'red')+
  scale_size_continuous(breaks = c(10, 30, 100, 200, 1200),
                        limits = c(0, 1200))

NEM

save_plot('Subcell_results/Subcell_NEM.png', width = 26, height = 15)

