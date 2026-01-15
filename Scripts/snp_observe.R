#!/usr/bin/env Rscript

# Load required libraries
suppressPackageStartupMessages({
  library(VariantAnnotation)
  library(argparse)
})

# Set up argument parser
parser <- ArgumentParser(description='Observe a particular SNP in a VCF file')
parser$add_argument('vcf_file', help='Path to the VCF file')
parser$add_argument('location', help='SNP location in format chr:position')
parser$add_argument('sample_name', help='Name of the sample to observe')

args <- parser$parse_args()

# Function to observe SNP
observe_snp <- function(vcf_file, location, sample_name) {
  # Parse location
  loc_parts <- strsplit(location, ":")[[1]]
  chromosome <- loc_parts[1]
  position <- as.integer(loc_parts[2])
  
  # Read VCF file
  vcf <- readVcf(vcf_file, genome="hg19")
  
  # Check if sample exists
  if (!sample_name %in% samples(header(vcf))) {
    stop(paste("Error: Sample", sample_name, "not found in the VCF file."))
  }
  
  # Extract the specific SNP
  snp <- vcf[rowRanges(vcf)$seqnames == chromosome & start(vcf) == position]
  
  if (length(snp) == 0) {
    cat(paste("No SNP found at", location, "\n"))
    return()
  }
  
  # Get genotype
  gt <- geno(snp)$GT[1, sample_name]
  
  # Get alleles
  ref_allele <- as.character(ref(snp))
  alt_alleles <- as.character(alt(snp)[[1]])
  
  # Interpret genotype
  alleles <- c(ref_allele, alt_alleles)
  gt_numeric <- as.numeric(strsplit(gt, "|", fixed=TRUE)[[1]]) + 1
  genotype <- paste(alleles[gt_numeric], collapse="/")
  
  # Print results
  cat(paste("SNP at", location, "\n"))
  cat(paste("Reference allele:", ref_allele, "\n"))
  cat(paste("Alternate allele(s):", paste(alt_alleles, collapse=", "), "\n"))
  cat(paste("Genotype for", sample_name, ":", genotype, "\n"))
}

# Run the function with command line arguments
observe_snp(args$vcf_file, args$location, args$sample_name)
