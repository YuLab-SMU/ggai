# Case D - Cross-paper schematic synthesis
# Generates the meta-level BioRender-style aging schematic via ggai_generate_image()
suppressMessages(devtools::load_all(quiet = TRUE))
ggai_load_env()

out_dir <- "dev_docs/figures/case-D"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

prompt_meta <- "
A clean, publication-ready BioRender-style scientific schematic for a Nature Aging-style
review paper. The figure title at the top center reads in clean serif:
'Aging stressor --> molecular trigger --> tissue dysfunction'.

Below the title, draw exactly FIVE parallel vertical lanes, labelled A through E.
Each lane represents one published Nature Aging study. Lanes are separated by
thin pale grey vertical guides. Every lane follows the same four-row layout
from top to bottom:

ROW 1 (tissue icon, large circular badge with soft pastel fill):
  Lane A: a stylised liver organ icon (warm amber).
  Lane B: a skeletal muscle bundle icon (deep red striations).
  Lane C: a human brain icon with dopaminergic neurons highlighted (lavender).
  Lane D: a red blood cell / HSC bone-marrow icon (crimson).
  Lane E: a mouse brain coronal section with three regions colour-coded (teal).

ROW 2 (upstream trigger, small icon + 2-word caption in italic):
  Lane A: an iron ion 'Fe2+' surrounded by lipid peroxides; caption 'Iron + ROS'.
  Lane B: three branched-chain amino acid molecules; caption 'BCAA accumulation'.
  Lane C: alpha-synuclein protein aggregate; caption 'Protein aggregation'.
  Lane D: a pyrimidine molecule with a downward arrow; caption 'Uridine deficit'.
  Lane E: a clock superimposed on a brain coronal slice; caption 'Spatiotemporal drift'.

ROW 3 (downstream pathway, rounded rectangle in saturated pastel):
  Lane A: 'Ferroptosis' (slate-blue rectangle).
  Lane B: 'mTOR dysregulation' (olive rectangle).
  Lane C: 'Integrin / lipid signalling' (mauve rectangle).
  Lane D: 'FoxO signalling' (rose rectangle).
  Lane E: 'PRC2 / inflammaging' (teal rectangle).

ROW 4 (phenotype, simple line icon + 3-4 word label):
  Lane A: 'MASLD + fibrosis'.
  Lane B: 'Sarcopenia + frailty'.
  Lane C: 'Parkinson''s disease'.
  Lane D: 'HSC exhaustion'.
  Lane E: 'Cognitive decline'.

Connect ROW 1 -> ROW 2 -> ROW 3 -> ROW 4 within each lane using thin downward
arrows. Above each lane place a small monospace tag exactly:
  Lane A: 'Paper #14  MASLD'
  Lane B: 'Paper #16  Sarcopenia'
  Lane C: 'Paper #20  Parkinson'
  Lane D: 'Paper #21  Blood / HSC'
  Lane E: 'Paper #37  Mouse brain'

At the bottom, ACROSS ALL FIVE LANES, a single orange horizontal banner stripe
(soft tangerine #f3a96a) reads in white bold serif:
  'Common theme: metabolic-immune-cell-death axis'

Use a calm BioRender palette (amber, mauve, slate-blue, olive, teal, crimson).
White background. Clean serif font for headings; lighter sans-serif for body
captions. No drop shadows. No watermarks. No extraneous text. No journal logos.
Strictly schematic, no realistic photographs. The figure must read top-to-bottom
within each lane and left-to-right across lanes. Aspect ratio 1536x1024."

cat("[case-D] sending prompt to gpt-image-2 ...\n")

attempt <- function(retry_left = 2L) {
  tryCatch(
    ggai_generate_image(
      model      = ggai_image_model(),
      prompt     = prompt_meta,
      output_dir = tempdir(),
      width      = 1536,
      height     = 1024,
      quality    = "high"
    ),
    error = function(e) {
      msg <- conditionMessage(e)
      cat(sprintf("[case-D] error: %s\n", msg))
      if (retry_left > 0L && grepl("5\\d\\d|timeout|temporar", msg, ignore.case = TRUE)) {
        cat("[case-D] retrying in 8s ...\n")
        Sys.sleep(8)
        attempt(retry_left - 1L)
      } else {
        stop(e)
      }
    }
  )
}

t0 <- Sys.time()
res <- attempt()
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("[case-D] API ok in %.1fs\n", elapsed))

dst <- file.path(out_dir, "meta-aging-schematic.png")
file.copy(res$images[[1]]$path, dst, overwrite = TRUE)
cat(sprintf("[case-D] saved -> %s\n", dst))
