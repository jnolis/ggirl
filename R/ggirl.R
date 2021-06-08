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
