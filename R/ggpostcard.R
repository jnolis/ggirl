#' Order postcards of your ggplot!
#'
#' This function takes a ggplot2 output and will send postcards of it for you!
#' Running this function will bring you to a webpage to confirm the order and submit it.
#' _No order will be submitted until you explicitly approve it._
#'
#'
#' @param plot the plot to put on the front of the postcard
#' @param contact_email email address to send order updates
#' @param return_address the return address for the postcard (required)
#' @param messages either a message to use with all of the recipients, or a list of messages of the same length as the list of addresses (one for each address).
#' @param send_addresses either a result of the "address()" function, or a list of results of the "address()" function.
#' @param ... other options to pass to ggsave when turning the plot into an image for the front of the postcard
#' @examples
#' library(ggplot2)
#' library(ggirl)
#' return_address <- address(name = "Jacqueline Nolis", address_line_1 = "111 North St",
#'                           city = "Seattle", state = "WA",
#'                           postal_code = "11111", country = "US")
#' contact_email <- "fakeemailforreal@gmail.com"
#' send_address_1 <- address(name = "Fake Personname", address_line_1 = "250 North Ave",
#'                           city = "Boston", state = "MA",
#'                           postal_code = "22222", country = "US")
#' send_address_2 <- address(name = "Anotherfake personname",
#'                           address_line_1 = "15 NE 36th St", address_line_2 = "Apt 4",
#'                           city = "Redmond", state = "WA",
#'                           postal_code = "33333", country = "US")
#'
#' plot <- ggplot(data.frame(x=1:10, y=runif(10)),aes(x=x,y=y))+geom_line()+geom_point()
#'
#' # send to one recipient
#' ggpostcard(plot, contact_email, return_address, messages = "An example postcard", send_addresses = send_address_1)
#'
#' # send the same message to multiple recipients
#' ggpostcard(plot, contact_email, return_address, messages = "An example postcard", send_addresses = list(send_address_1, send_address_2))
#'
#' # send different messages to multiple recipients
#' ggpostcard(plot, contact_email, return_address, messages = c("message for sender 1","message for sender 2"), send_addresses = list(send_address_1, send_address_2))
#' @export
ggpostcard <- function(plot=last_plot(), contact_email, return_address, messages, send_addresses, ...){
  max_message_length <- 750

  if(any(nchar(messages) > max_message_length)){
    stop(paste0("Messages can be at most ", max_message_length," characters"))
  }

  if(inherits(send_addresses,"ggirl_address") && length(messages) == 1){
    # Single recipient
    messages_and_send_addresses <-
      list(list(message = messages, send_address = send_addresses))
  } else if(all(sapply(send_addresses,function(x) inherits(x,"ggirl_address")))){
    # List of recipients
    if(length(messages) == 1){
      # recycle the message
      messages_and_send_addresses <-
        lapply(send_addresses, function(x) list(message = messages, send_address = x))
    } else {
      messages_and_send_addresses <- mapply(function(message, send_address) list(message = message, send_address = send_address),
                                            messages, send_addresses, SIMPLIFY = FALSE)
      messages_and_send_addresses <- unname(messages_and_send_addresses)
    }
  }

  version <- packageDescription("ggirl", fields = "Version")
  if(is.na(version)){
    version <- "0.0.0"
  }

  server_url <- getOption("ggirl_server_url",
                          "https://skyetetra.shinyapps.io/ggirl-server")

  # in the event the server is sleeping, we need to kickstart it before doing the post
  invisible(httr::GET(server_url))

  temp_png <- tempfile(fileext = ".png")
  on.exit({file.remove(temp_png)}, add=TRUE)
  cut_margin <- 0.02
  safe_margin <- 0.03
  postcard_width_px <- 1875
  postcard_height_px <- 1275
  postcard_content_width_px <- postcard_width_px - 2*ceiling(postcard_width_px*safe_margin)
  postcard_content_height_px <- postcard_height_px - 2*ceiling(postcard_width_px*safe_margin)
  postcard_dpi <- 300
  ggplot2::ggsave(filename = temp_png, plot=plot, width = postcard_content_width_px/postcard_dpi, height = postcard_content_height_px/postcard_dpi, dpi = postcard_dpi, ...)
  raw_plot <- readBin(temp_png, "raw", file.info(temp_png)$size)

  data <- list(
    type = "postcard",
    contact_email = contact_email,
    raw_plot = raw_plot,
    return_address = return_address,
    messages_and_send_addresses = messages_and_send_addresses,
    version = version
  )

  zz <- rawConnection(raw(0), "r+")
  on.exit({close(zz)}, add=TRUE)
  saveRDS(data, zz)
  seek(zz, 0)

  response <- httr::POST(paste0(server_url, "/upload"),
                   body = rawConnectionValue(zz),
                   httr::content_type("application/octet-stream"))
  if(response$status_code != 201L){
    stop(httr::content(response, as="text", encoding="UTF-8"))
  }
  token <- httr::content(response, as="text", encoding="UTF-8")
  browseURL(paste0(server_url,"/postcard?token=",token))
}
