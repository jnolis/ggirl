
artprint_dpi <- 300

artprint_size_info <-
  data.frame(
    size = c("11x14", "16x20", "18x24", "24x36", "12x12", "16x16", "20x20"),
    price_cents = c(2750L, 3250L, 3750L, 5000L, 2750L, 3250L, 3750L),
    width_in =  c(11L, 16L, 18L, 24L, 12L, 16L, 20L),
    height_in = c(14L, 20L, 24L, 36L, 12L, 16L, 20L)
    )

ggartprint_sizes <- function(){
  info <- artprint_size_info[,c("size","price_cents","width_in","height_in")]
  info_names <- c("size","price","width_inches","height_inches")
  info$price <- paste0("$", sprintf("%.2f",info$price/100))
  info
}

ggartprint_save <- function(filename, plot, size, orientation = c("landscape","portrait"), ...){
  orientation <- match.arg(orientation)
  size_info <- as.list(artprint_size_info[artprint_size_info$size == size,])
  if(is.null(size_info$size)){
    stop("Invalid size list selected. Use ggartprint_sizes() to see available sizes")
  }

  if(orientation == "landscape"){
    width <- size_info$height_in
    height <- size_info$width_in
  } else {
    width <- size_info$width_in
    height <- size_info$height_in
  }

  ggplot2::ggsave(filename = filename, plot=plot, device = "png",
                    width = width, height = height, dpi = artprint_dpi, ...)
}

ggartprint <- function(plot, size, orientation, contact_email, address, quantity=1, ...){

  if(any(address$country != "US")){
    stop("Art prints only available for US addresses through package. Email support@ggirl.art to price a custom order.")
  }

  version <- packageDescription("ggirl", fields = "Version")
  if(is.na(version)){
    version <- "0.0.0"
  }

  server_url <- getOption("ggirl_server_url",
                          "https://skyetetra.shinyapps.io/ggirl-server")

  # in the event the server is sleeping, we need to kickstart it before doing the post
  response <- httr::GET(server_url)
  if(response$status_code != 200L){
    message("Waiting 10 seconds for ggirl server to come online")
    Sys.sleep(10)
  }

  temp_png <- tempfile(fileext = ".png")
  on.exit({file.remove(temp_png)}, add=TRUE)
  ggartprint_save(filename = temp_png, plot=plot, size = size, orientation = orientation, ...)
  raw_plot <- readBin(temp_png, "raw", file.info(temp_png)$size)

  data <- list(
    type = "artprint",
    contact_email = contact_email,
    raw_plot = raw_plot,
    address = address,
    size = size,
    orientation = orientation,
    quantity = quantity,
    version = version
  )

  zz <- rawConnection(raw(0), "r+")
  on.exit({close(zz)}, add=TRUE)
  saveRDS(data, zz)
  seek(zz, 0)

  response <- httr::POST(paste0(server_url, "/upload"),
                         body = rawConnectionValue(zz),
                         httr::content_type("application/octet-stream"))
  if(response$status_code == 403L){
    stop("Cannot connect to ggirl server. Go to https://ggirl.art/status to see latest status updates")
  }
  if(response$status_code != 201L){
    stop(httr::content(response, as="text", encoding="UTF-8"))
  }
  token <- httr::content(response, as="text", encoding="UTF-8")
  browseURL(paste0(server_url,"/artprint?token=",token))
}
