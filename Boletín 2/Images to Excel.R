
library(openxlsx)
library(png)  # For reading PNG dimensions

## Images to Excel ----

setwd('/Users/vero/Library/CloudStorage/GoogleDrive-savaldiviesofl@flacso.edu.ec/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Boletín 2')


# --- 1. CONFIGURATION ---
image_folder <- "Graficos" 
output_file <- "Organized_Graphs.xlsx"


# --- 2. SETUP ---
files <- list.files(image_folder, pattern = "\\.png$", full.names = TRUE)
file_names <- basename(files)

get_topic <- function(filename) {
  parts <- unlist(strsplit(filename, "_"))
  return(parts[1])
}

topics <- unique(sapply(file_names, get_topic))

wb <- createWorkbook()

title_style <- createStyle(
  halign = "center", 
  valign = "center", 
  textDecoration = "bold", 
  fontSize = 12,
  border = "Bottom"
)

# --- 3. PROCESSING ---
for (topic in topics) {
  addWorksheet(wb, topic)
  
  topic_files <- files[sapply(file_names, get_topic) == topic]
  topic_filenames <- file_names[sapply(file_names, get_topic) == topic]
  
  current_row <- 2
  
  for (i in seq_along(topic_files)) {
    
    # -- A. CREATE TITLE --
    clean_title <- sub("\\.png$", "", topic_filenames[i])
    writeData(wb, topic, clean_title, startCol = 1, startRow = current_row)
    mergeCells(wb, topic, cols = 1:7, rows = current_row)
    addStyle(wb, topic, title_style, rows = current_row, cols = 1:7, gridExpand = TRUE)
    
    # -- B. INSERT IMAGE WITH PRESERVED ASPECT RATIO --
    # Read image to get dimensions
    img_info <- readPNG(topic_files[i], native = FALSE, info = TRUE)
    img_width <- attr(img_info, "info")$dim[1]   # width in pixels
    img_height <- attr(img_info, "info")$dim[2]  # height in pixels
    
    # Calculate aspect ratio
    aspect_ratio <- img_width / img_height
    
    # Set target width (7 columns ≈ 5.6 inches)
    target_width <- 5.6
    
    # Calculate height based on aspect ratio
    target_height <- target_width / aspect_ratio
    
    # Insert image with calculated dimensions
    insertImage(wb, topic, topic_files[i], 
                startRow = current_row + 1, 
                startCol = 1,
                width = target_width,
                height = target_height,
                units = "in")
    
    # -- C. UPDATE ROW COUNTER --
    # Convert height in inches to approximate rows (1 row ≈ 0.2 inches)
    image_rows <- ceiling(target_height / 0.2)
    rows_to_skip <- 1 + image_rows + 2  # 1 for title + image rows + 2 padding
    current_row <- current_row + rows_to_skip
  }
  
  setColWidths(wb, topic, cols = 1:7, widths = 12)
}

# --- 4. SAVE ---
saveWorkbook(wb, output_file, overwrite = TRUE)

message(paste("File created successfully:", output_file))

