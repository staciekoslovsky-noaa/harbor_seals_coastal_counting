# Coastal Pv Surveys: Generate image list for counting
# S. Koslovsky

# Set variables --------------------------------------------------
photog_date_id <- 'HLZ_20260807'
counter <- 'Stacie Koslovsky'

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

# Run code -------------------------------------------------------
year <- substr(photog_date_id, 5, 8)
date <- paste(
  substr(photog_date_id, 5, 8),
  substr(photog_date_id, 9, 10),
  substr(photog_date_id, 11, 12),
  sep = '-'
)
photographer <- substr(photog_date_id, 1, 3)

# Connect to DB
con <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("mml_pep_db"),
  host = Sys.getenv("mml_pep_ip"),
  user = Sys.getenv("mml_pep_user"),
  password = Sys.getenv("mml_pep_user_pw")
)

to_be_counted <- RPostgres::dbGetQuery(
  con,
  paste0(
    "SELECT source_file FROM surv_pv_cst.tbl_image_exif WHERE photog_date_id = \'",
    photog_date_id,
    "\' AND use_for_count_lku = \'Y\' ORDER BY source_file"
  )
)

# Insert records into tbl_image_count
images <- basename(to_be_counted$source_file)
for (i in 1:length(images)) {
  RPostgres::dbSendQuery(
    con,
    paste0(
      "INSERT INTO surv_pv_cst.tbl_image_count (image_name, count_type_lku, count_by, count_compromised, representative) SELECT \'",
      images[i],
      "\', \'P\', \'",
      counter,
      "\', \'False\', \'False\' WHERE NOT EXISTS (SELECT image_name FROM surv_pv_cst.tbl_image_count WHERE image_name = \'",
      images[i],
      "\')"
    )
  )
}

# Create folders, as needed
counted_folder <- 'G:\\Shared drives\\NMFS MML PEP Survey Harbor Seal Coastal\\Counts\\'

if (file.exists(paste0(counted_folder, year))) {
  if (file.exists(paste0(counted_folder, year, '\\', date))) {
    if (
      file.exists(paste0(counted_folder, year, '\\', date, '\\', photographer))
    ) {
      print("Folder already exists")
      setwd(file.path(paste0(
        counted_folder,
        year,
        '\\',
        date,
        '\\',
        photographer
      )))
    } else {
      dir.create(file.path(paste0(
        counted_folder,
        year,
        '\\',
        date,
        '\\',
        photographer
      )))
      setwd(file.path(paste0(
        counted_folder,
        year,
        '\\',
        date,
        '\\',
        photographer
      )))
    }
  } else {
    dir.create(file.path(paste0(counted_folder, year, '\\', date)))
    dir.create(file.path(paste0(
      counted_folder,
      year,
      '\\',
      date,
      '\\',
      photographer
    )))
    setwd(file.path(paste0(
      counted_folder,
      year,
      '\\',
      date,
      '\\',
      photographer
    )))
  }
} else {
  dir.create(file.path(paste0(counted_folder, year)))
  dir.create(file.path(paste0(counted_folder, year, '\\', date)))
  dir.create(file.path(paste0(
    counted_folder,
    year,
    '\\',
    date,
    '\\',
    photographer
  )))
  setwd(file.path(paste0(counted_folder, year, '\\', date, '\\', photographer)))
}

# Export image list to newly created folder
write.table(
  to_be_counted,
  paste0("coastalPv_", photog_date_id, "_rgb_images.txt"),
  row.names = FALSE,
  col.names = FALSE,
  quote = FALSE
)
