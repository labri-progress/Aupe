# Shared simulation parameters — sourced by all fig*.r scripts.
nodes       <- 1000
view        <- 20
nruns       <- 1
faulty_pcts <- c(10, 20, 30, 40)
results_dir <- "output_byz"
height      <- 3 #2.5

# ── Thème ─────────────────────────────────────────────────────────────────────
size <- 14
mytheme <- theme(
  panel.grid.major        = element_line(color = "gray90",  linewidth = 0.50),
  panel.grid.minor        = element_line(color = "gray95",  linewidth = 0.25),
  panel.background        = element_rect(fill = "white"),
  plot.background         = element_rect(fill = "white"),
  panel.border            = element_rect(colour = "black", linewidth = 1, fill = NA),
  legend.spacing.y        = unit(0.005, "cm"),
  text                    = element_text(size = size, color = "black"),
  axis.title.x            = element_text(size = size, face = "bold"),
  axis.title.y            = element_text(size = size, face = "bold"),
  axis.text.x             = element_text(size = size - 1, face = "bold"),
  axis.text.y             = element_text(size = size - 1, face = "bold"),
  plot.title              = element_text(size = size, face = "bold"),
  legend.text             = element_text(size = size, face = "bold"),
  legend.title            = element_blank(),
  legend.background       = element_rect(fill = "transparent", colour = NA),
  legend.box.background   = element_rect(fill = "transparent", colour = NA),
  legend.key.height       = unit(9,  "pt"),
  plot.margin             = margin(5.5, 0, 5.5, 0, "pt"),
  axis.ticks              = element_line(color = "black", linewidth = 1),
  axis.ticks.length       = unit(4, "pt"),
  axis.minor.ticks.length = unit(2, "pt")
) + theme(
  axis.ticks.x.top         = element_line(color = "black", linewidth = 1),
  axis.ticks.y.right       = element_line(color = "black", linewidth = 1),
  axis.minor.ticks.x.top   = element_line(color = "black", linewidth = 0.5),
  axis.minor.ticks.y.right  = element_line(color = "black", linewidth = 0.5),
  axis.text.x.top          = element_blank(),
  axis.text.y.right        = element_blank()
)