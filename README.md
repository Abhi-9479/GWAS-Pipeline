# End-to-End GWAS Pipeline
```markdown
# WES/NGS → VCF → PLINK → PCA → Association → Plots

A reproducible Snakemake workflow to run an end-to-end GWAS starting from **aligned BAMs** (or plug in your own alignment step) and producing:
- **Joint-called + VQSR-recalibrated** variants (GATK4)
- **SNP/INDEL split + annotation** (bcftools/dbSNP IDs)
- **PLINK binary datasets** + QC reports
- **Population structure PCs** (EIGENSOFT/smartpca) + covariates
- **PC-adjusted association testing** (PLINK logistic regression)
- **QQ and Manhattan plots** (R scripts)

> Built to run well on AWS (EC2) and other Linux/HPC environments.

---

## What this pipeline does

### Variant processing (GATK best-practice-ish)
1. Mark duplicates (GATK MarkDuplicatesSpark)
2. Base quality score recalibration (BaseRecalibratorSpark + ApplyBQSRSpark)
3. Scatter intervals (SplitIntervals)
4. Per-sample GVCF calling (HaplotypeCaller, GVCF mode)
5. Gather interval GVCFs (GatherVcfs)
6. Joint genotyping (CombineGVCFs → GenotypeGVCFs)
7. Variant Quality Score Recalibration (VQSR) for SNPs then INDELs
8. Split into SNPs and INDELs (SelectVariants)
9. Add dbSNP IDs (bcftools annotate)

### GWAS preparation + QC (PLINK)
- VCF → PLINK bed/bim/fam for SNPs + INDELs
- QC summaries:
  - allele frequencies
  - missingness (per-sample/per-variant)
  - Hardy–Weinberg tests
- Filtering:
  - MAF / missingness / HWE thresholds
- LD pruning + heterozygosity
- Sex check + relatedness (IBD)

### PCA + covariates + association
- Run smartpca (EIGENSOFT)
- Build covariate file (PC1–PC10 + population label)
- Run PLINK logistic regression adjusted by PCs
- Generate QQ + Manhattan plots (R)

---

## Repository layout (recommended)

```

.
├── Snakefiles/
│   ├── Gatk_haplo.snake      # GATK → annotated VCF → PLINK convert
│   ├── gwas_1.snake          # PLINK QC + filtering + pruning + IBD/sex checks
│   ├── gwas_2.snake          # smartpca run + param generation
│   ├── gwas3.snake           # PCA plots (R)
│   └── gwas4.snake           # covariates + GWAS + QQ/Manhattan (R)
├── sample_sheet.csv
├── scripts/
│   ├── plot_pcs.R
│   ├── plot_pop.R
│   ├── plot_qq.R
│   └── plot_man.R
└── README.md

````

---

## Inputs

### 1) `sample_sheet.csv`
Minimum columns expected:
- `name` (unique sample name; used as index)
- `condition` (used to expand targets)
- `replicate` (optional; used for grouping/expansion)

Example:

```csv
name,condition,replicate
S01,case,1
S02,control,1
S03,case,2
````

### 2) Reference + known-sites (hg38/GRCh38)

Place in your reference directory (example names):

* `Homo_sapiens_assembly38.fasta`
* `Homo_sapiens_assembly38.dbsnp138.vcf(.gz)`
* `Mills_and_1000G_gold_standard.indels.hg38.vcf.gz`
* `hapmap_3.3.hg38.vcf.gz`
* `1000G_omni2.5.hg38.vcf.gz`

### 3) Aligned BAMs (current assumption)

The provided GATK Snakefile expects sorted BAMs here:

```
/data/results_exome/bwa/sort/{sample}_sorted.bam
```

If you want FASTQ → BAM inside the same pipeline, add rules for:

* BWA-MEM alignment
* sorting + indexing
  and set those outputs as inputs to MarkDuplicates.

---

## Outputs (high level)

* Final joint VCF:

  * `/data/results_exome/gatk/hc/final.vcf.gz`
  * `/data/results_exome/gatk/vqsr/final.recalibrated.vcf.gz`
* Analysis-ready split:

  * `analysis-ready-snps.vcf.gz`
  * `analysis-ready-indels.vcf.gz`
* Annotated VCFs:

  * `snps_annotated.vcf`
  * `indels_annotated.vcf`
* PLINK:

  * `/data/results_exome/gwas/plink/**`
* PCA:

  * `/data/results_exome/gwas/smartpca/test.evec(.eval/.out)`
* Association:

  * `/data/results_exome/gwas/results_gwas/*.assoc.logistic`
* Plots:

  * QQ + Manhattan images (saved under your environment/plots path)

---

## Requirements

### Core

* Snakemake (recommended: `>=7`)
* Python 3
* GATK4
* bcftools
* PLINK 1.9/2.0
* EIGENSOFT (smartpca)

### R (for plots)

* R + basic packages used by your plotting scripts (qq/manhattan/PCA plotting)

---

## Quickstart (AWS-friendly)

### 1) Launch an EC2 instance

A typical setup:

* Ubuntu/Amazon Linux
* Enough storage (EBS) for BAM/VCF intermediate files
* Attach an IAM role if pulling references/data from S3

### 2) Install tools

Use conda/mamba or modules:

* snakemake
* gatk
* plink
* bcftools
* eigensoft
* R

### 3) Run the pipeline

From repo root:

```bash
# Variant calling + VQSR + PLINK conversion
snakemake -s Snakefiles/Gatk_haplo.snake -j 16 --rerun-incomplete

# PLINK QC / filtering / pruning / IBD / sex-check
snakemake -s Snakefiles/gwas_1.snake -j 8 --rerun-incomplete

# PCA (smartpca)
snakemake -s Snakefiles/gwas_2.snake -j 4 --rerun-incomplete

# PCA plots
snakemake -s Snakefiles/gwas3.snake -j 2 --rerun-incomplete

# Covariates + GWAS + QQ/Manhattan
snakemake -s Snakefiles/gwas4.snake -j 4 --rerun-incomplete
```

> Tip: Start with a small `-j` to validate paths, then scale up.

---

## Configuration tips (so it runs on YOUR machine)

The Snakefiles currently use absolute paths like:

* `SAMPLES_DIR = "/data/samples"`
* `RESULTS_DIR = "/data/results_exome"`
* `REF_DIR = "/data/ref"`
* `ENV_DIR = "/home/ec2-user/environment"`

**Recommended improvement:** move these into a `config.yaml` and reference via `config["RESULTS_DIR"]` etc.

Example `config.yaml`:

```yaml
SAMPLES_DIR: /data/samples
RESULTS_DIR: /data/results_exome
REF_DIR: /data/ref
ENV_DIR: /home/ec2-user/environment
SCATTER_COUNT: 20
```

---

## Notes on phenotype & covariates

* This workflow builds a covariate file containing PCs (PC1–PC10).
* If you have a case/control phenotype file, PLINK can take it via `--pheno`.
* Population labels in the current covariate generation step are mapped from sample prefixes (e.g., CA/EA/PA). Adjust this logic to match your cohort.

---

## Reproducibility

Recommended additions:

* `--use-conda` and environment YAMLs per rule
* `snakemake --report report.html`
* Pin versions in `environment.yml` or Docker

---

## Data & privacy

Do **not** commit:

* raw FASTQs / BAMs / VCFs
* patient identifiers
* access keys or credentials

Add these to `.gitignore`:

```
data/
results/
*.bam
*.bai
*.vcf
*.vcf.gz
*.tbi
.env
```

---

## Citation

If you use/extend this pipeline, please cite:

* GATK4 best practices (Broad Institute)
* PLINK
* EIGENSOFT (smartpca)

---

## Contact

By: **Abhyuday Parihar**
CooperSurgicals

```
