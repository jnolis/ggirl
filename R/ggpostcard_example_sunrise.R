get_sunrise_sunset_single_day <- function(coordinates, date, tz){
  response <- httr::GET(glue::glue("https://api.sunrise-sunset.org/json?lat={coordinates$lat}",
                                   "&lng={coordinates$long}&date={date}&formatted=0"))
  results <- httr::content(response)$results

  results[["day_length"]] <- NULL
  results <- lapply(results, function(x) as.POSIXct(x,format="%Y-%m-%dT%T",tz="UTC"))
  results <- lapply(results, function(x) lubridate::with_tz(x, tzone = tz))
  results
}

get_year_dates <- function(year = NULL){
  if(is.null(year)){
    year <- lubridate::year(Sys.time())
  }
  start_date <- as.Date(paste0(year,"-01-01")) - lubridate::days(3)
  end_date <- as.Date(paste0(year + 1,"-01-01")) + lubridate::days(3)
  seq.Date(start_date,end_date,by="day")
}


mem_get_sunrise_sunset_single_day <- memoise::memoise(get_sunrise_sunset_single_day)



get_sunrise_sunsets <- function(lat, long, tz, year, progress = TRUE){

  dates <- get_year_dates(year)

  message("Querying api: https://sunrise-sunset.org/api")
  if(progress){
    pb <- progress::progress_bar$new(format = "  calling sunrise/sunset api [:bar] :percent eta: :eta",
                                     total = length(dates))
  }

  if(exists("mem_get_sunrise_sunset_single_day")){
    get_fun <- mem_get_sunrise_sunset_single_day
  } else {
    get_fun <- get_sunrise_sunset_single_day
  }
  datetimes <- lapply(dates, function(d){
    pb$tick()
    get_fun(list(lat = lat, long = long), d, tz)
  })
  result <- do.call(rbind,lapply(datetimes,as.data.frame))
  result$date <- dates
  result
}


format_sunrise_info <- function(sunrise_info, year, tz){
  night_type_lookup <- data.frame(
    name =
      c("sunrise", "sunset",
        "civil_twilight_begin", "civil_twilight_end",
        "nautical_twilight_begin", "nautical_twilight_end",
        "astronomical_twilight_begin", "astronomical_twilight_end"),
    night_group =
      c("sunrise/sunset", "sunrise/sunset",
        "civil_twilight", "civil_twilight",
        "nautical_twilight", "nautical_twilight",
        "astronomical_twilight", "astronomical_twilight"),
    night_type =
      c("begin", "end",
        "begin", "end",
        "begin", "end",
        "begin", "end")
  )

  si_long <- tidyr::pivot_longer(sunrise_info, -date)
  y_origin <- as.POSIXct(as.Date(paste0(year,"-01-01")), tz="UTC")

  strip_date <- function(local_time,origin,tz){
    stripped <- y_origin +
      lubridate::seconds(as.numeric(difftime(local_time,
                                             as.POSIXct(paste0(lubridate::ymd(origin)," 00:00:00"),tz=tz),
                                             units="secs")))
    stripped <- lubridate::with_tz(stripped, tz = "UTC")
    stripped[stripped < as.Date("1972-01-01")] <- NA
    stripped
  }

  si_long <- dplyr::left_join(si_long,night_type_lookup, by = "name")

  si_long_begin <- dplyr::filter(si_long,night_type == "begin")
  si_long_noon <- dplyr::filter(si_long,is.na(night_type))
  si_long_end <- dplyr::filter(si_long,night_type == "end")

  si_long_begin_joined <-
    dplyr::inner_join(
      dplyr::select(si_long_begin, date, name, night_group, begin_value = value),
      dplyr::mutate(dplyr::select(si_long_end,
                                  date, night_group,
                                  end_value = value),
                    date = date + lubridate::days(1)),
      by = c("night_group","date"))

  si_long_end_joined <-
    dplyr::inner_join(
      dplyr::select(si_long_end, date, name, night_group, end_value = value),
      dplyr::mutate(dplyr::select(si_long_begin,
                                  date, night_group,
                                  begin_value = value),
                    date = date - lubridate::days(1)),
      by = c("night_group","date"))

  si_long_lines <- dplyr::mutate(si_long_noon,
                                 stripped_value = strip_date(value, date, tz))

  si_long_areas <- dplyr::bind_rows(si_long_begin_joined, si_long_end_joined)
  si_long_areas <- dplyr::mutate(si_long_areas,
                                 begin_stripped_value = strip_date(begin_value, date, tz),
                                 end_stripped_value = strip_date(end_value, date, tz))


  list(si_long_areas = si_long_areas, si_long_lines = si_long_lines, y_origin = y_origin, year = year)
}

make_sunrise_plot_simple <- function(formatted_sunrise_info){
  plot_order <- function(name){
    factor(name,
           levels =rev(c("astronomical_twilight_begin",
                         "nautical_twilight_begin",
                         "civil_twilight_begin",
                         "sunrise",
                         "solar_noon",
                         "astronomical_twilight_end",
                         "nautical_twilight_end",
                         "civil_twilight_end",
                         "sunset"
           )))
  }

  year <- formatted_sunrise_info$year
  y_origin <- formatted_sunrise_info$y_origin
  si_long_areas<- formatted_sunrise_info$si_long_areas
  si_long_lines <- formatted_sunrise_info$si_long_lines

  si_long_areas$plot_order <- plot_order(si_long_areas$name)

  light_color <- "#D0D0D8"
  dark_color <- "#181820"

  very_light_blue <- "#c5d2fa"
  light_blue <- "#95abf0"
  mid_blue <- "#7691e3"
  dark_blue <- "#4a65b6"
  very_dark_blue <- "#343e6b"
  black <- "#0A0D29"

  pretty_time <- function(times){
    paste0(as.numeric(format(times,format = "%I", tz = "UTC")),
           tolower(format(times,format = "%p", tz = "UTC")))
  }

  colors <- c(black, very_dark_blue, dark_blue, mid_blue, black, very_dark_blue,dark_blue, mid_blue)
  ggplot2::ggplot() +
    ggplot2::geom_ribbon(data = si_long_areas,
                         ggplot2::aes(x = date,
                                      ymin = begin_stripped_value,
                                      ymax = end_stripped_value,
                                      fill = plot_order)) +
    ggplot2::geom_line(data = si_long_lines,
                       ggplot2::aes(x=date,y=stripped_value),
                       color = dark_blue)+
    ggplot2::coord_cartesian(ylim = y_origin+lubridate::hours(c(0,24)),
                             xlim = c(as.Date(paste0(year,"-01-01")), as.Date(paste0(year+1,"-01-01")))) +
    ggplot2::scale_y_datetime(breaks = y_origin+lubridate::hours(c(0,6,12,18,24)),
                              expand = ggplot2::expansion(0,0),
                              labels = pretty_time)+
    ggplot2::scale_x_date(expand = ggplot2::expansion(0,0),
                          date_labels = "%b")+
    ggplot2::geom_hline(data=data.frame(yintercept = y_origin +
                                          lubridate::hours(c(0, 6, 12, 18, 24))),
                        ggplot2::aes(yintercept=yintercept), color=light_color, size=0.65, alpha=0.5)+
    ggplot2::geom_hline(data=data.frame(yintercept = y_origin +
                                          lubridate::hours(seq(0,24,3))),
                        ggplot2::aes(yintercept=yintercept), color=light_color, size=0.325, alpha=0.5)+
    ggplot2::geom_hline(data=data.frame(yintercept = y_origin +
                                          lubridate::hours(seq(-1,25,1))),
                        ggplot2::aes(yintercept=yintercept), color=light_color, size=0.125, alpha=0.5)+
    ggplot2::geom_vline(data=data.frame(xintercept = seq.Date(as.Date(y_origin), as.Date(y_origin + lubridate::days(366)), by="3 months")),
                        ggplot2::aes(xintercept=xintercept), color=light_color, size=0.625, alpha=0.5)+
    ggplot2::geom_vline(data=data.frame(xintercept = seq.Date(as.Date(y_origin), as.Date(y_origin + lubridate::days(366)), by="month")),
                        ggplot2::aes(xintercept=xintercept), color=light_color, size=0.125, alpha=0.5)+
    ggplot2::scale_fill_manual(values = rev(colors)) +
    ggplot2::theme_minimal(8) +
    ggplot2::theme(panel.background = ggplot2::element_rect(fill = very_light_blue, size = 0, color = NA),
                   panel.border = ggplot2::element_blank(),
                   plot.background = ggplot2::element_rect(fill = dark_color, size = 0, color = NA),
                   panel.grid =ggplot2:: element_blank(),
                   legend.title = ggplot2::element_blank(),
                   legend.text = ggplot2::element_text(color = light_color),
                   axis.title = ggplot2::element_blank(),
                   axis.text = ggplot2::element_text(size = ggplot2::rel(1.8), color = light_color),
                   axis.text.y = ggplot2::element_text(margin = ggplot2::margin(r = 5)),
                   axis.text.x = ggplot2::element_text(margin = ggplot2::margin(t = 5)),
                   plot.title = ggplot2::element_text(size = ggplot2::rel(4), color = light_color, margin = ggplot2::margin(b=3)),
                   plot.subtitle = ggplot2::element_text(size = ggplot2::rel(1.25), color = light_color,
                                                         margin = ggplot2::margin(b=15,t=0)),
                   plot.margin = ggplot2::margin(r = 30, t=30, l = 30, b=30),
                   plot.caption = ggplot2::element_text(size = ggplot2::rel(0.8), color = light_color),
                   plot.title.position = "plot",
                   plot.caption.position = "plot",
                   legend.position="none"
    ) +
    ggplot2::labs(title = location_name,
                  subtitle = paste0("Night | Astronomical Twilight | Nautical Twilight | Civil Twilight | Daylight"))

}

#' An example postcard with the sunrise and sunset times for a location
#'
#' This example makes a postcard with a pretty ggplot that gives you when sunrise
#' and sunset is over the course of the year.
#'
#' To get the longitude and latitude for your location, you can click a place in Google maps.
#' To get the time zone, you can use the \href{https://en.wikipedia.org/wiki/List_of_tz_database_time_zones}{Wikipedia list of time zone codes}
#'
#' This function uses an external API \href{https://sunrise-sunset.org/api}{https://sunrise-sunset.org/api}. While the package has some built-in caching,
#' _if you call the function with too many locations in a short period of time your IP will be temporarily blocked_.
#'
#' If all of the inputs are NULL, the function defaults to using Seattle, Washington.
#'
#' @param location_lat the latitude of the location
#' @param location_long the longitude of the location
#' @param location_tz a tz time zone string of the style taken by R functions like as.POSIXct
#' @param location_name string for the name to show for the location (ex: "Seattle, WA")
#' @return a ggplot2 plot to pass to ggpostcard
#' @family ggpostcard_examples
#' @examples
#' library(ggirl)
#' location_lat <- 47.6062
#' location_long <- -122.3321
#' location_tz <- "America/Los_Angeles"
#' location_name <- "Seattle, WA"
#' return_address <- address(name = "Jacqueline Nolis", address_line_1 = "111 North St",
#'                           city = "Seattle", state = "WA",
#'                           postal_code = "11111", country = "US")
#' contact_email <- "fakeemailforreal@gmail.com"
#' send_addresses <- address(name = "Fake Personname", address_line_1 = "250 North Ave",
#'                           city = "Boston", state = "MA",
#'                           postal_code = "22222", country = "US")
#' messages <- "Look at this cool plot I found!"
#' plot <- ggpostcard_example_sunrise(location_lat, location_long, location_tz, location_name)
#' ggpostcard(plot = plot,
#'   contact_email = contact_email, return_address = return_address,
#'   send_addresses = send_addresses, messages = messages)
#' @export
ggpostcard_example_sunrise <- function(location_lat = NULL, location_long = NULL, location_tz = NULL, location_name = NULL, year = NULL, ...){
  required_packages <- c("lubridate", "progress", "tidyr", "dplyr")
  packages_is_installed <- sapply(required_packages, function(x) requireNamespace(x, quietly = TRUE))

  if (any(!packages_is_installed)) {
    stop(paste0("This example requires you to install these packages: ",
                paste0(required_packages[!packages_is_installed], collapse = ", ")),
         call. = FALSE)
  }

  if(is.null(year)){
    year <- lubridate::year(Sys.Date())
  }

  if(is.null(location_lat) || is.null(location_long) || is.null(location_tz) || is.null(location_name)){
    stop("Must supply location_lat, location_long, location_tz, and location_name")
  }

  sunrise_info <- get_sunrise_sunsets(location_lat, location_long, location_tz, year)
  formatted_sunrise_info <- format_sunrise_info(sunrise_info, year, location_tz)
  plot <- make_sunrise_plot_simple(formatted_sunrise_info)
  plot
}
