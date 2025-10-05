# --- CONFIG ---

file1 <- "mergebm-200-200-2"
file2 <- "bm-200-2"

library(dplyr)
# --- LOAD DATA ---
df1 <- read.table(file1, header = TRUE) 
df2 <- read.table(file2, header = TRUE) 

# --- SANITY CHECK ---
cat("File1 columns:", names(df1), "\n")
cat("File2 columns:", names(df2), "\n")

# --- MERGE ON ROUND ---
merged <- merge(df1, df2, by = "time", suffixes = c("_f1", "_f2"))

# --- VERIFY ---
cat("Merged rows:", nrow(merged), "\n")

# --- COMPUTE DIFFERENCE ---
if ("avgByzN_f1" %in% names(merged) && "avgByzN_f2" %in% names(merged)) {
  merged$diff <- (merged$avgByzN_f1 - merged$avgByzN_f2)/16
} else {
  stop("Both files must have a column named 'avgByzN'")
}

# --- PLOT ---
plot(merged$time, merged$diff, type = "l", col = "blue", pch = 19,
     xlab = "Round", ylab = "Difference (MergeBM(t=200) - BM)",
     main = "Comparison across rounds Budget=2KB N=1000 Faulty=200")
abline(h = 0, col = "red", lty = 2)