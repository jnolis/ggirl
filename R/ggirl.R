#' Create an address object
#'
#' This function takes string inputs and converts them into an address object that can be used to send irl art (or as a return address).
#'
#' @param name The name for the address
#' @param address_line_1 The first line of the address
#' @param address_line_2 (Optional) A second address line, such as an apartment number.
#' @param city the city
#' @param state (Optional) The state to send to
#' @param postal_code The postal code (ZIP code in the US)
#' @param country The 2-character [ISO-1366 code](https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes) for the country. Non-US shipping is experimental!
#'
#' @examples
#' send_address <- address(name = "RStudio", address_line_1 = "250 Northern Ave",
#'   city = "Boston", state = "MA", postal_code = "02210", country = "US")
#'
#' @export
address <- function(name,
                    address_line_1,
                    address_line_2 = NULL,
                    city,
                    state = NULL,
                    postal_code,
                    country){
  address_set <- list(name = name,
                      address_line_1 = address_line_1,
                      address_line_2 = address_line_2,
                      city = city,
                      state = state,
                      postal_code = postal_code,
                      country = country)
  # Check country is valid
  if (!is.character(country) || nchar(country) != 2){
    stop("Country must be a 2-character ISO-1366 code (https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes)")
  }

  structure(address_set, class="ggirl_address")
}

#' Get the server URL
#'
#' This function gets the most current server URL by using a fixed lookup URL
get_server_url <- function(){
  server_url <- getOption("ggirl_server_url", "https://ggirl-server.community.saturnenterprise.io")

  tryCatch({
    httr::RETRY(
      verb = "GET",
      url = server_url,
      times = 2,
      pause_min = 5,
      pause_cap = 5,
      quiet = TRUE,
      httr::timeout(5)
    )
  }, error = function(e){
    stop("ggirl server is not connecting--try updating the ggirl package or email ggirl@jnolis.com")
  })

  server_url
}


#' Get package version
#'
#' @return the version of the package being used
get_version <- function(){
  version <- packageDescription("ggirl", fields = "Version")
  if(is.na(version)){
    version <- "0.0.0"
  }
  version
}


#' Upload data
#'
#' This function will upload the data to the server, then launch the page for it
upload_data_and_launch <- function(data, server_url, type){
  zz <- rawConnection(raw(0), "r+")
  on.exit({close(zz)}, add=TRUE)
  saveRDS(data, zz)
  seek(zz, 0)

  tryCatch({
    response <- httr::RETRY(
      verb = "POST",
      url = paste0(server_url, "/upload"),
      body = rawConnectionValue(zz),
      pause_min = 3,
      pause_cap = 10,
      quiet = TRUE,
      httr::content_type("application/octet-stream")
    )
    token <- httr::content(response, as="text", encoding="UTF-8")
    browseURL(paste0(server_url,"/", type, "?token=",token))
  }, error = function(e){
    stop("Plot upload failed--try updating the ggirl package or email ggirl@jnolis.com")
  })
}
