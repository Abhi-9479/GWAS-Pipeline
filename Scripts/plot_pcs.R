## Usage: Rscript --vanilla plot_PCs.R filename x y NPC output_file
## Assumes filename is a smartpca file with Number of PCs+2 columns
## x and y are PC (numbers), NPC is the number of PCs in the file
## output_file is the path to save the plot

# Parse command-line arguments
args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 5) {
  stop("Usage: Rscript --vanilla plot_PCs.R filename x y NPC output_file")
}

infile <- args[1]
x <- as.numeric(args[2])
y <- as.numeric(args[3])
N <- as.numeric(args[4])
output_file <- args[5]

# Check if file exists
if (!file.exists(infile)) {
  stop("Input file does not exist.")
}

# Read the file
yy <- read.table(infile, header=FALSE, skip=1,
                  col.names=c("ID", paste("PC", 1:N, sep=""), "CASE"),
                  as.is=TRUE)

# Check if the indices are within range
if (x > N || y > N) {
  stop("PC indices are out of range.")
}

# Create a JPEG file
jpeg(output_file)

# Plot
plot(yy[, x+1], yy[, y+1],
     col=as.numeric(as.factor(yy[, N+2])),
     xlab=paste("PC", x, sep=""),
     ylab=paste("PC", y, sep=""))

# Close the device
dev.off()
