watercolor_dpi <- 300
watercolor_width <- 10
watercolor_height <- 8

#' Preview your watercolor request
#'
#' This function takes a ggplot2 output and gives a preview of how plot will be requested to be painted.
#' While it's totally fine to just call ggirl::ggwatercolor to preview, this allows you to preview locally.
#'
#' The preview will appear in either the "Viewer" pane of RStudio or in your browser, depending on if RStudio is installed or not.
#' The preview includes a frame, but that will not be included with the print.
#'
#' @param plot the plot to use as an art print
#' @param orientation should the plot be landscape or portrait?
#' @param ... other options to pass to `ragg::agg_png()` when turning the plot into an image.
#' @seealso [ggwatercolor()] to request the watercolor commission
#' @examples
#' library(ggplot2)
#' library(ggirl)
#' plot <- ggplot(data.frame(x=1:10, y=runif(10)),aes(x=x,y=y))+geom_line()+geom_point()+theme_gray(48)
#' ggwatercolor_preview(plot, orientation = "landscape")
#' @export
ggwatercolor_preview <- function(plot, size, orientation, ...){
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

.watercolor {
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
    <img src="plot.png" class = "watercolor">
  </div>
  </div>
  </body>
</html>
  '

  ggwatercolor_save(filename = temp_plot_file, plot = plot, orientation = orientation, ...)
  writeLines(css, temp_css_file)
  writeLines(html, temp_html_file)
  viewer <- getOption("viewer")
  if (!is.null(viewer))
    viewer(temp_html_file)
  else
    utils::browseURL(temp_html_file)
}

ggwatercolor_save <- function(filename, plot, orientation = c("landscape","portrait"), ...){
  orientation <- match.arg(orientation)

  if(orientation == "portrait"){
    width <- watercolor_height
    height <- watercolor_width
  } else if(orientation == "landscape") {
    width <- watercolor_width
    height <- watercolor_height
  } else {
    stop("invalid orientation")
  }

  old_dev <- grDevices::dev.cur()
  ragg::agg_png(
    filename,
    width = width,
    height = height,
    units = "in",
    res = watercolor_dpi,
    ...)

  on.exit(utils::capture.output({
    grDevices::dev.off()
    if (old_dev > 1) grDevices::dev.set(old_dev)
  }))

  grid::grid.draw(plot)

}


#' Request a watercolor commission of your ggplot!
#'
#' This function takes a ggplot2 output and request a handpainted watercolor painting of it!
#' Running this function will bring you to a webpage to confirm the request--a followup email will contain the details and how to pay.
#' _No painting will be made until after an email exchange and the payment sent._
#'
#' Watercolor paintings will be made 8"x10" on 140lb cold-press paper with professional light-safe paints.
#' Since these are painted by hand, they may not be exactly accurate to the original, and may be simplified
#' depending on the complexity of the original (which will be discussed by email).
#'
#' The paintings take up to 4 weeks to be delivered.
#'
#' @param plot the plot to use as an art print.
#' @param orientation should the plot be landscape or portrait?
#' @param contact_email email address to send order updates.
#' @param quantity the number of prints to order (defaults to 1).
#' @param address the physical address to mail the painting to. Use the [address()] function to format it.
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
#' ggwatercolor(plot, orientation = "landscape",
#'            contact_email = contact_email, address = delivery_address)
#' @export
ggwatercolor <- function(plot, orientation = c("landscape","portrait"), contact_email, address, ...){

  orientation <- match.arg(orientation)
  if(any(address$country != "US")){
    stop("Art prints only available for US addresses through package. Email support@ggirl.art to price a custom order.")
  }

  version <- get_version()
  server_url <- get_server_url()

  temp_png <- tempfile(fileext = ".png")
  on.exit({file.remove(temp_png)}, add=TRUE)
  ggwatercolor_save(filename = temp_png, plot=plot, orientation = orientation, ...)
  raw_plot <- readBin(temp_png, "raw", file.info(temp_png)$size)

  data <- list(
    type = "watercolor",
    contact_email = contact_email,
    raw_plot = raw_plot,
    address = address,
    orientation = orientation,
    version = version
  )

  upload_data_and_launch(data, server_url, "watercolor")
}
