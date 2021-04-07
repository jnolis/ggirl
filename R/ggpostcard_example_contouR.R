
#' An example postcard with art from the contouR package
#'
#' This example makes a postcard with a beautiful graphic using the \href{https://github.com/Ijeamakaanyene/contouR}{contouR package} by Ijeamaka Anyene.
#'
#' @param background_col (optional) the background color of the plot
#' @param line_col (optional) the color of the lines in the plot
#' @return a ggplot2 plot to pass to ggpostcard
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
#' plot <- ggpostcard_example_contouR()
#' ggpostcard(plot = plot, contact_email = contact_email, return_address = return_address,
#'   send_addresses = send_addresses, messages = messages)
#' @export
ggpostcard_example_contouR <- function(background_col = NULL, line_col = NULL){
  if(!requireNamespace("contouR", quietly = TRUE)) {
    stop("This example requires you to install the contouR package: remotes::install_github(Ijeamakaanyene/contouR)",
         call. = FALSE)
  }
  if(is.null(background_col)){
    background_col = "#e9ebed"
  }
  if(is.null(line_col)){
    line_col = "#2a3c4b"
  }

  setup <- contouR::contour_grid(grid_size = 30, point_dist = .25, z_method = "runif", z = 1, z_span = 3)
  setup <- contouR::contour_shape(setup, radius = 10.2, x_center = 7, y_center = 7, ring_system = "multiple",
                                  num_rings = 10)

  plot <- contouR::contour_plot(setup$grid_shape, rings = setup$rings,
                                background_col = background_col, line_col = line_col) +
    ggplot2::xlim(1, 30) +
    ggplot2::ylim(1, 30/postcard_content_width_px*postcard_content_height_px)

  plot
}
