get_map_data <- function(coordinates){
  required_packages <- c("osmdata", "sf")
  packages_is_installed <- sapply(required_packages, function(x) requireNamespace(x, quietly = TRUE))
  if (any(!packages_is_installed)) {
    stop(paste0("This example requires you to install these packages: ",
                paste0(required_packages[!packages_is_installed], collapse = ", ")),
         call. = FALSE)
  }
  create_sf <- function(key, value, coordinates){
    result <- osmdata::opq(coordinates)
    result <- osmdata::add_osm_feature(result, key = key, value = value)
    result <- osmdata::osmdata_sf(result)
  }

  big_streets <- create_sf(key = "highway",
                           value = c("motorway", "primary", "motorway_link", "primary_link"),
                           coordinates)

  med_streets <- create_sf(key = "highway",
                           value = c("secondary", "tertiary", "secondary_link", "tertiary_link"),
                           coordinates)

  small_streets <- create_sf(key = "highway",
                             value = c("residential", "living_street",
                                       "unclassified",
                                       "service", "footway"
                             ),
                             coordinates)

  railway <- create_sf(key = "railway", value="rail", coordinates)

  list(big_streets = big_streets, med_streets = med_streets, small_streets = small_streets, railway = railway)
}

mem_get_map_data <- memoise::memoise(get_map_data)


#' Make a print of a map in R
#'
#' This example uses Open Street Map data to make a print of a map. It's based
#' on a tutorial by [Joshua McCrain](http://joshuamccrain.com/tutorials/maps/streets_tutorial.html).
#'
#' The location of the map is either derived from the header string ("{title}, {subtitle}"), or can
#' be specified precisely using the coordinates option.
#'
#' The sizing was tested using an 11"x14" print with portrait orientation--other sizes and shapes will require
#' adjusting the text size using the `text_rel_sizes` parameter.
#'
#' It's recommended you pass ggartprint the parameter `background="#FEFDF7"` to avoid having white margins around the print.
#'
#' @param title The larger top line of text above the plot, if coordinates not specified also used to find the map location
#' @param subtitle The smaller lower line of text above the plot, if coordinates not specified also used to find the map location
#' @param coordinates (optional) exactly the location for the map. Needs to be a matrix with row names `c("x","y")` and column names `c("min","max")`.
#' Ex: `matrix(c(-122.460,47.481, -122.224,47.734), nrow=2, dimnames = list(c("x","y"),c("min","max")))`
#' @param colors (optional) a named vector of colors to use for the plot. Defaults to
#' `c(back = "#FEFDF7", grid = "#FCF3DB", text = "#474973", axis_text = "#E1C886", roads = "#474973", trains = "#474973")`
#' @param text_rel_sizes (optional) the relative sizes of the text to use. Defaults to `c(title = 3.5, subtitle = 2.5, axis = 0.4)`
#'
#' @return a ggplot2 plot to pass to ggartprint
#' @family ggartprint_examples
#' @examples
#' library(ggirl)
#' contact_email <- "fakeemailforreal@gmail.com"
#' delivery_address <- address(name = "Fake Personname", address_line_1 = "250 North Ave",
#'                           city = "Boston", state = "MA",
#'                           postal_code = "22222", country = "US")
#' plot <- ggartprint_example_map("Seattle", "Washington")
#' # use the background option to avoid white boundaries
#' ggartprint(plot, background = "#FEFDF7", size = "11x14", orientation = "portrait",
#'                                 contact_email = contact_email,
#'                                 address = delivery_address)
#' @export
ggartprint_example_map <- function(title, subtitle, coordinates = NULL, colors = NULL, text_rel_sizes = NULL){
  if(is.null(coordinates)){
    coordinates <- osmdata::getbb(paste0(title,", ", subtitle))
  }

  if(is.null(colors)){
    colors <- c(back = "#FEFDF7",
                grid = "#FCF3DB",
                text = "#474973",
                axis_text = "#E1C886",
                roads = "#474973",
                trains = "#474973"
    )
  }

  if(is.null(text_rel_sizes)){
    text_rel_sizes <- c(
      title = 3.5,
      subtitle = 2.5,
      axis = 0.4
    )
  }
  message("Downloading Open Street Map data (or using cache)")
  data <- mem_get_map_data(coordinates)

  plot <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = data$railway$osm_lines,
                     inherit.aes = FALSE,
                     color = colors[["trains"]],
                     size = .2,
                     linetype="dotdash",
                     alpha = .5) +
    ggplot2::geom_sf(data = data$med_streets$osm_lines,
                     inherit.aes = FALSE,
                     color = colors[["roads"]],
                     size = .3,
                     alpha = .5) +
    ggplot2::geom_sf(data = data$small_streets$osm_lines,
                     inherit.aes = FALSE,
                     color = colors[["roads"]],
                     size = .2,
                     alpha = .3) +
    ggplot2::geom_sf(data = data$big_streets$osm_lines,
                     inherit.aes = FALSE,
                     color = colors[["roads"]],
                     size = .5,
                     alpha = .6) +
    ggplot2::coord_sf(xlim = c(coordinates["x","min"], coordinates["x","max"]),
                      ylim = c(coordinates["y","min"], coordinates["y","max"]),
                      expand = FALSE)+
    ggplot2::labs(title = title, subtitle = subtitle)+
    ggplot2::theme_gray(24)+
    ggplot2::theme(
      axis.text = ggplot2::element_text(color = colors[["axis_text"]], size = rel(text_rel_sizes[["axis"]])),
      axis.ticks = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(size = rel(text_rel_sizes[["title"]]), color = colors[["text"]], margin = ggplot2::margin(20), hjust=0.5),
      plot.subtitle = ggplot2::element_text(size = rel(text_rel_sizes[["subtitle"]]), color = colors[["text"]], hjust=0.5),
      plot.background = ggplot2::element_rect(fill=colors[["back"]]),
      panel.background = ggplot2::element_rect(fill=colors[["back"]]),
      panel.grid.major = ggplot2::element_line(color = colors[["grid"]], size = ggplot2::rel(0.5)),
      panel.border = ggplot2::element_rect(color = colors[["grid"]], fill = NA, size = ggplot2::rel(0.5)),
      panel.spacing.x = ggplot2::unit(40,"pt"),
      plot.margin = ggplot2::margin(40,40,30,40),
      plot.title.position = "plot")
}
