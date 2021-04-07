
#' An example postcard with art from the rstereogram package
#'
#' This example makes a postcard where if you cross your eyes you see a secret image!
#' It uses the package {rstereogram} by Ryan Timpe.
#'
#' *Depending on the size of the image preview the image may be distorted.*
#' Try zooming in and out of the picture on your monitor to see the effect.
#'
#' The default image is the R logo, however you can pass your own PNG file.
#' Suggestions for your own file:
#' * It should have the aspect ratio 5.875in x 3.875in
#' * It should be grayscale
#' * It should be a small file (height around 500 pixels)
#'
#' @param image_filename (optional) The path of the PNG file to be the image. If NULL defaults to the R logo
#' @param colors (optional) vector of visually distinct colors to make the image
#' @param alpha_only (optional) If the alpha channel of the png file
#' @return a ggplot2 plot to pass to ggpostcard
#' @family ggpostcard_examples
#' @examples
#' library(ggirl)
#' return_address <- address(name = "Jacqueline Nolis", address_line_1 = "111 North St",
#'                           city = "Seattle", state = "WA",
#'                           postal_code = "11111", country = "US")
#' contact_email <- "fakeemailforreal@gmail.com"
#' send_addresses <- address(name = "Fake Personname", address_line_1 = "250 North Ave",
#'                           city = "Boston", state = "MA",
#'                           postal_code = "22222", country = "US")
#' messages <- "Look at this cool plot I found!"
#' plot <- ggpostcard_example_rstereogram()
#' ggpostcard(plot = plot, contact_email = contact_email, return_address = return_address,
#'   send_addresses = send_addresses, messages = messages)
#' @export
ggpostcard_example_rstereogram <- function(image_filename = NULL, colors = c("#00436b", "#ffed89"), alpha_only = FALSE, ...){
  required_packages <- c("rstereogram","png")
  packages_is_installed <- sapply(required_packages, function(x) requireNamespace(x, quietly = TRUE))

  if (any(!packages_is_installed)) {
    stop(paste0("This example requires you to have rstereogram and png packages installed.",
                " You can install them with remotes::install_github('ryantimpe/rstereogram') and install.packages('png')"),
         call. = FALSE)
  }

  if(is.null(image_filename)){
    image_filename <- system.file("extdata", "r-logo-grayscale-small.png", package = "ggirl", mustWork = TRUE)
  }

  encoded_image <- rstereogram::image_to_magiceye(
    image = png::readPNG(image_filename),
    colors = colors,
    alpha_only = alpha_only
    )

  plot <- rstereogram::ggmagiceye(encoded_image)

  plot
}
