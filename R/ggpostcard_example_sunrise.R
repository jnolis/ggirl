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
  start_date <- as.Date(paste0(year,"-01-01"))
  end_date <- as.Date(paste0(year + 1,"-01-01"))
  seq.Date(start_date,end_date,by="day")
}

mem_get_sunrise_sunset_single_day <- memoise::memoise(get_sunrise_sunset_single_day)

get_sunrise_sunsets <- function(lat, long, tz, dates = NULL, progress = TRUE){
  message("Querying api: https://sunrise-sunset.org/api")
  if(is.null(dates)){
    dates <- get_year_dates()
  }
  if(progress){
    pb <- progress::progress_bar$new(format = "  calling sunrise/sunset api [:bar] :percent eta: :eta",
                                     total = length(dates))
  }

  datetimes <- lapply(dates, function(d){
    pb$tick()
    mem_get_sunrise_sunset_single_day(list(lat = lat, long = long), d, tz)
  })
  result <- do.call(rbind,lapply(datetimes,as.data.frame))
  result$date <- dates
  result
}

format_sunrise_info <- function(sunrise_info, tz){
  si_long <- tidyr::pivot_longer(sunrise_info, -date)

  y_origin <- as.POSIXct(min(si_long$date),tz="UTC")

  strip_date <- function(local_time,origin,tz){
    stripped <- y_origin +
      lubridate::seconds(as.numeric(difftime(local_time,
                                             as.POSIXct(paste0(lubridate::ymd(origin)," 00:00:00"),tz=tz),
                                             units="secs")))
    lubridate::with_tz(stripped, tz = "UTC")
  }
  si_long$stripped_value <- strip_date(si_long$value, si_long$date, tz)

  si_long$name_pretty <- factor(si_long$name,
                                levels =rev(c("astronomical_twilight_begin",
                                              "nautical_twilight_begin",
                                              "civil_twilight_begin",
                                              "sunrise",
                                              "solar_noon",
                                              "sunset",
                                              "civil_twilight_end",
                                              "nautical_twilight_end",
                                              "astronomical_twilight_end")),
                                labels = rev(c("Astronomical twilight (start)",
                                               "Nautical twilight (start)",
                                               "Civil twilight (start)",
                                               "Sunrise",
                                               "Solar noon",
                                               "Sunset",
                                               "Civil twilight (end)",
                                               "Nautical twilight (end)",
                                               "Astronomical twilight (end)")))

  strip_to_bottom <- c("astronomical_twilight_begin",
                       "nautical_twilight_begin",
                       "civil_twilight_begin",
                       "sunrise",
                       "solar_noon")
  si_long$stripped_value[lubridate::year(si_long$value) < 1970 & si_long$name %in% strip_to_bottom] <- y_origin - lubridate::hours(1)
  si_long$stripped_value[lubridate::year(si_long$value) < 1970 & !(si_long$name %in% strip_to_bottom)] <- y_origin + lubridate::hours(25)
  si_long$stripped_value[si_long$stripped_value > y_origin + lubridate::hours(25)] <- y_origin + lubridate::hours(25)
  si_long$stripped_value[si_long$stripped_value < y_origin - lubridate::hours(1)] <- y_origin - lubridate::hours(1)
  si_long
}

make_sunrise_plot <- function(sunrise_info, location_name, tz){
  si_long <- format_sunrise_info(sunrise_info, tz)
  y_origin <- as.POSIXct(min(si_long$date),tz="UTC")
  colors <- c("#0A0D29","#343e6b", "#4a65b6", "#adcaea", "#dfe8ee",
              "#f8eede", "#e0af8b", "#ec6137", "#a44d6f", "#39283f")
  light_color <- "#D0D0D0"
  dark_color <- "#181818"
  pretty_time <- function(times){
    paste0(as.numeric(format(times,format = "%I", tz = "UTC")),
           tolower(format(times,format = "%p", tz = "UTC")))
  }

  ggplot2::ggplot(si_long, ggplot2::aes(x=date, group = name_pretty)) +
    ggplot2::geom_ribbon(ggplot2::aes(fill = name_pretty, ymax=stripped_value), ymin = 0, show.legend = FALSE) +
    ggplot2::geom_line(ggplot2::aes(y = stripped_value), color = light_color, size = 0.5, lineend = "square", linejoin = "mitre") +
    ggplot2::geom_hline(data=data.frame(yintercept = y_origin +
                                 lubridate::hours(c(0, 6, 12, 18, 24))),
                        ggplot2::aes(yintercept=yintercept), color=light_color, size=0.65, alpha=0.5)+
    ggplot2::geom_hline(data=data.frame(yintercept = y_origin +
                                 lubridate::hours(seq(0,24,3))),
                        ggplot2::aes(yintercept=yintercept), color=light_color, size=0.325, alpha=0.5)+
    ggplot2::geom_hline(data=data.frame(yintercept = y_origin +
                                 lubridate::hours(seq(-1,25,1))),
                        ggplot2::aes(yintercept=yintercept), color=light_color, size=0.125, alpha=0.5)+
    ggplot2::geom_vline(data=data.frame(xintercept = min(si_long$date)+months(seq(0,12,3))),
                        ggplot2::aes(xintercept=xintercept), color=light_color, size=0.25, alpha=0.5)+
    ggplot2::geom_vline(data=data.frame(xintercept = min(si_long$date)+months(seq(0,12,1))),
                        ggplot2::aes(xintercept=xintercept), color=light_color, size=0.125, alpha=0.5)+
    ggplot2::scale_fill_manual(values = rev(colors[1:9])) +
    ggplot2::scale_x_date(expand = ggplot2::expansion(0,0))+
    ggplot2::scale_y_datetime(labels = pretty_time,
                     breaks = min(si_long$date)+lubridate::hours(c(0,6,12,18,24)),
                     limits = min(si_long$date)+lubridate::hours(c(-1,25)),
                     expand = ggplot2::expansion(0,0))+
    ggplot2::theme_minimal(8) +
    ggplot2::theme(panel.background = ggplot2::element_rect(fill = colors[10], size = 0, color = NA),
          panel.border = ggplot2::element_blank(),
          plot.background = ggplot2::element_rect(fill = dark_color, size = 0, color = NA),
          panel.grid =ggplot2:: element_blank(),
          legend.title = ggplot2::element_blank(),
          legend.text = ggplot2::element_text(color = light_color),
          axis.title = ggplot2::element_blank(),
          axis.text = ggplot2::element_text(size = ggplot2::rel(1.8), color = light_color),
          plot.title = ggplot2::element_text(size = ggplot2::rel(4), color = light_color, margin = ggplot2::margin(b=3)),
          plot.subtitle = ggplot2::element_text(size = ggplot2::rel(1.5), color = light_color),
          plot.margin = ggplot2::margin(r = 30, t=30, l = 30, b=30),
          plot.caption = ggplot2::element_text(size = ggplot2::rel(0.6), color = light_color),
          plot.title.position = "plot",
          plot.caption.position = "plot"
    ) +
    ggplot2::labs(title = location_name,
         subtitle = "Sunrise and sunset",
         caption = paste0(rev(levels(si_long$name_pretty)), collapse = " | "))
}

#' An example postcard with the sunrise and sunset times for a location
#'
#' This example makes a postcard with a pretty ggplot that gives you when sunrise
#' and sunset is over the course of the year.
#'
#' To get the longitude and latitude for your location, you can click a place in Google maps.
#' To get the time zone, you can use the Wikipedia list of time zone codes: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
#'
#' This function uses an external API (https://sunrise-sunset.org/api). While the package has some built-in caching,
#' _if you call the function with too many locations in a short period of time your IP will be temporarily blocked_.
#'
#' @param location_lat the latitude of the location
#' @param location_long the longitude of the location
#' @param location_tz a tz time zone string of the style taken by R functions like as.POSIXct
#' @param location_name string for the name to show for the location (ex: "Seattle, WA")
#' @param ... other options to pass to ggpostcard()
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
#' ggpostcard_example_sunrise(location_lat, location_long, location_tz, location_name,
#'   contact_email = contact_email, return_address = return_address,
#'   send_addresses = send_addresses, messages = messages)
#' @export
ggpostcard_example_sunrise <- function(location_lat, location_long, location_tz, location_name, ...){
  sunrise_info <- get_sunrise_sunsets(location_lat, location_long, location_tz)
  plot <- make_sunrise_plot(sunrise_info, location_name, location_tz)
  ggpostcard(plot = plot, ...)
}
