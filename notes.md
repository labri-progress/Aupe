Scripts produits

# fig1_evolution_strategies.r

Rscript fig1_evolution_strategies.r <budget> [zoom_from zoom_to]
Grille 2×2 (10/20/30/40% byz), 3 courbes par panneau : Aupe Array (bleu ciel), Aupe BM (violet), Aupe BMDecay (noir). Ligne pointillée verticale au round 10 000, référence horizontale y=f/100. Zoom avec time_step=5 au lieu de 100.

# fig2_convergence_summary.r

Rscript fig2_convergence_summary.r <budget>
Figure unique, x = % byz dans le système, y = propByz à la convergence (moyenne rounds > 11 000). Stratégies : Basalt (orange/cercle), Brahms (vermillion/triangle), Aupe BMDecay (noir/carré). Référence y=f/100 en tiretés.

# fig3_merge_gain.r

Rscript fig3_merge_gain.r <budget>
Figure unique, x = % byz, y = gain absolu = propByz_sans_merge − propByz_avec_merge à convergence. Trois courbes : t=5% (orange), t=10% (bleu ciel), t=20% (vert). Référence y=0.

# fig4_attack_comparison.r

Rscript fig4_attack_comparison.r <budget> [zoom_from zoom_to]
Grille 2×2. Couleur = merge % (t=0% noir, 5% orange, 10% bleu, 20% vert) ; type de ligne = attaque (Camouflage / decay2 en solide, Soudaine / decay4 en tiretés). Deux guides de légende séparés. Zoom disponible.

# fig5_kmeans_nodes.r

Rscript fig5_kmeans_nodes.r <strategy> <faulty_pct> [budget] [t_count] [p_merge] [round_from] [round_to]
Lit le fichier nodes-*, filtre les rounds [round_from, round_to] (défaut : 11000–11049), calcule la moyenne de avgByzN/view par nœud, exclut les byzantins (node_id < F), applique KMeans k=2 (le cluster à moyenne plus faible → Trusted). Affiche Precision/Recall/F1 et produit un PDF : (1) courbes de densité par classe vraie + frontière KMeans, (2) heatmap de la matrice de confusion.

Conventions communes : palette Okabe-Ito cohérente entre figures, thème épuré double-axe (axes secondaires sans labels), ligne verticale pointillée au round 10 000 dans les figures d'évolution, fichiers cherchés dans output_byz/, PDFs sauvegardés dans results/.