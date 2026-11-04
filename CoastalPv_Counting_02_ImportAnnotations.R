# Import coastal harbor seal annotations to DB
# S. Koslovsky

# Set variables --------------------------------------------------
photog_date_id <- 'HLZ_20260807'
file_name <- 'coastalPv_HLZ_20260807_rgb_annotations.csv'

# Create functions -----------------------------------------------
# Function to install packages needed
install_pkg <- function(x) {
  if (!require(x, character.only = TRUE)) {
    install.packages(x, dep = TRUE)
    if (!require(x, character.only = TRUE)) stop("Package not found")
  }
}

# Install libraries ----------------------------------------------
install_pkg("RPostgres")
install_pkg("DBI")
install_pkg("tidyverse")

# Process data ---------------------------------------------------

# Set up working environment
"%notin%" <- Negate("%in%")

counted_folder <- 'G:\\Shared drives\\NMFS MML PEP Survey Harbor Seal Coastal\\Counts\\'
year <- substr(photog_date_id, 5, 8)
date <- paste(
  substr(photog_date_id, 5, 8),
  substr(photog_date_id, 9, 10),
  substr(photog_date_id, 11, 12),
  sep = '-'
)
photographer <- substr(photog_date_id, 1, 3)

wd <- paste0(counted_folder, year, '\\', date, '\\', photographer)
setwd(wd)

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("mml_pep_db"),
  host = Sys.getenv("mml_pep_ip"),
  user = Sys.getenv("mml_pep_user"),
  password = Sys.getenv("mml_pep_user_pw")
)

# Delete data from tables, if previously imported
RPostgres::dbSendQuery(
  con,
  paste0(
    "DELETE FROM surv_pv_cst.tbl_detections_manualreview_rgb WHERE photog_date_id = \'",
    photog_date_id,
    "\'"
  )
)

# Import data and process
manual_id <- RPostgres::dbGetQuery(
  con,
  "SELECT max(id) FROM surv_pv_cst.tbl_detections_manualreview_rgb"
)
manual_id$max <- ifelse(is.na(manual_id$max), 0, manual_id$max)

manual <- read.csv(
  file_name,
  skip = 2,
  header = FALSE,
  stringsAsFactors = FALSE,
  col.names = c(
    "detection",
    "image_name",
    "frame_number",
    "bound_left",
    "bound_top",
    "bound_right",
    "bound_bottom",
    "score",
    "length",
    "detection_type",
    "type_score"
  )
)

if (nrow(manual) > 0) {
  manual <- manual %>%
    filter(!is.na(frame_number)) %>%
    mutate(
      image_name = basename(sapply(
        strsplit(image_name, split = "\\/"),
        function(x) x[length(x)]
      ))
    ) %>%
    mutate(id = 1:n()) %>% # + manual_id$max) %>%
    mutate(detection_file = file_name) %>%
    mutate(photog_date_id = photog_date_id) %>%
    mutate(detection_id = paste(photog_date_id, detection, sep = "_")) %>%
    select(
      "id",
      "detection",
      "image_name",
      "frame_number",
      "bound_left",
      "bound_top",
      "bound_right",
      "bound_bottom",
      "score",
      "length",
      "detection_type",
      "type_score",
      "photog_date_id",
      "detection_id",
      "detection_file"
    )

  # Import data to DB
  target_table <- Id(
    schema = "surv_pv_cst",
    table = "tbl_detections_manualreview_rgb"
  )
  RPostgres::dbWriteTable(
    con,
    target_table,
    manual,
    append = TRUE,
    row.names = FALSE
  )
}

# Disconnect from DB
RPostgres::dbDisconnect(con)
rm(con)
