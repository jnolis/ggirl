artprint_dpi <- 300

artprint_size_info <-
  read.csv("https://storage.googleapis.com/ggirl-public/lookups/artprint-size-info.csv")

#' get a table of sizes of prints available.
#'
#' Prices include shipping. If a size isn't available that you want email ggirl@jnolis.com for custom sizes.
#' @export
ggartprint_sizes <- function(){
  info <- artprint_size_info[,c("size","price_cents","width_in","height_in")]
  info_names <- c("size","price","width_inches","height_inches")
  info$price <- paste0("$", sprintf("%.2f",info$price/100))
  info[,c("size","price")]
}


#' Preview your art print
#'
#' This function takes a ggplot2 output and gives a preview of how the plot will look as an art print.
#' While it's totally fine to just call ggirl::ggartprint to preview, this allows you to preview locally.
#'
#' The preview will appear in either the "Viewer" pane of RStudio or in your browser, depending on if RStudio is installed or not.
#' The preview includes a frame, but that will not be included with the print.
#'
#' @param plot the plot to use as an art print
#' @param size the size of the art print. Use [ggartprint_sizes()] to see a list of the sizes. If a size isn't available that you want email ggirl@jnolis.com for custom sizes.
#' @param orientation should the plot be landscape or portrait?
#' @param ... other options to pass to `ragg::agg_png()` when turning the plot into an image.
#' @seealso [ggartprint()] to order the art print
#' @examples
#' library(ggplot2)
#' library(ggirl)
#' plot <- ggplot(data.frame(x=1:10, y=runif(10)),aes(x=x,y=y))+geom_line()+geom_point()+theme_gray(48)
#' ggartprint_preview(plot, size="11x14", orientation = "landscape")
#' @export
ggartprint_preview <- function(plot, size, orientation, ...){
  temp_dir <- tempfile()
  dir.create(temp_dir)
  temp_plot_file <- file.path(temp_dir, "plot.png")
  temp_css_file <- file.path(temp_dir, "site.css")
  temp_html_file <- file.path(temp_dir, "index.html")
  mg <- ceiling(postcard_width_px*(safe_margin-cut_margin))
  css <- "body {margin: 0;}
.frame {
    background-color: #303030;
    box-shadow: 0 10px 7px -5px rgba(0, 0, 0, 0.3);
    padding: 1rem!important;
    margin: 1rem!important;
    display: inline-block;
}

.box-shadow {
    position: relative;
    text-align: center;
}

.box-shadow::after {
    box-shadow: 0px 0px 20px 0px rgba(0,0,0,0.5) inset;
    bottom: 0;
    content: '';
    display: block;
    left: 0;
    height: 100%;
    position: absolute;
    right: 0;
    top: 0;
    width: 100%;
}
.box-shadow img {
    max-width: 100%;
    width: auto;
    max-height: 90vh;
}

.artprint {
    max-width: 100%;
    height: auto;
}"

  html <- '
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>ggartprint preview</title>
    <link rel="stylesheet" href="site.css">
  </head>
  <body>
  <div class="frame">
  <div class="box-shadow">
    <img src="plot.png" class = "artprint">
  </div>
  </div>
  </body>
</html>
  '

  ggartprint_save(filename = temp_plot_file, plot = plot, size = size, orientation = orientation, ...)
  writeLines(css, temp_css_file)
  writeLines(html, temp_html_file)
  viewer <- getOption("viewer")
  if (!is.null(viewer))
    viewer(temp_html_file)
  else
    utils::browseURL(temp_html_file)
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
  } else if(orientation == "portrait") {
    width <- size_info$width_in
    height <- size_info$height_in
  } else {
    stop("invalid orientation")
  }

  old_dev <- grDevices::dev.cur()
  ragg::agg_png(
    filename,
    width = as.integer(width),
    height = as.integer(height),
    units = "in",
    res = artprint_dpi,
    ...)

  on.exit(utils::capture.output({
    grDevices::dev.off()
    if (old_dev > 1) grDevices::dev.set(old_dev)
  }))

  grid::grid.draw(plot)

}


#' Order art prints of your ggplot!
#'
#' This function takes a ggplot2 output and will order an art print to hang on a wall!
#' Running this function will bring you to a webpage to confirm the order and submit it.
#' _No order will be submitted until you explicitly approve it._
#'
#' You can choose from a number of options for the size of the print (and either rectangular or square).
#' All of the sizes are high resolution, so things like text size in the R/RStudio plot may not reflect what
#' it would look like as a poster. It's recommended you run the function a few times and adjust plot attributes
#' until you get it the way you like it. The preview image includes a frame, but that will not be included with the print.
#'
#' Prints take up to 2-3 weeks to deliver.
#'
#' @param plot the plot to use as an art print.
#' @param size the size of the art print. Use [ggartprint_sizes()] to see a list of the sizes. If a size isn't available that you want email ggirl@jnolis.com for custom sizes.
#' @param orientation should the plot be landscape or portrait?
#' @param contact_email email address to send order updates.
#' @param quantity the number of prints to order (defaults to 1).
#' @param address the physical address to mail the print(s) to. Use the [address()] function to format it.
#' @param ... other options to pass to `ragg::agg_png()` when turning the plot into an image for the front of the postcard.
#' @seealso [address()] to format an address for ggirl
#' @examples
#' library(ggplot2)
#' library(ggirl)
#' delivery_address <- address(name = "Fake person", address_line_1 = "101 12th st",
#'   address_line_2 = "Apt 17", city = "Seattle", state = "WA",
#'   postal_code = "98102", country = "US")
#' contact_email = "fakeemail275@gmail.com"
#' plot <- ggplot(data.frame(x=1:10, y=runif(10)),aes(x=x,y=y))+geom_line()+geom_point()+theme_gray(48)
#' ggartprint(plot, size="11x14", orientation = "landscape", quantity = 1,
#'            contact_email = contact_email, address = delivery_address)
#' @export
ggartprint <- function(plot, size = "11x14", orientation = c("landscape","portrait"),  quantity=1, contact_email, address, ...){

  orientation <- match.arg(orientation)
  if(any(address$country != "US")){
    stop("Art prints only available for US addresses through package. Email ggirl@jnolis.com to price a custom order.")
  }

  version <- get_version()
  server_url <- get_server_url()

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

  upload_data_and_launch(data, server_url, "artprint")
}
