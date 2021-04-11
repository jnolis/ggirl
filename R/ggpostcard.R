
cut_margin <- 0.02941176
safe_margin <- 0.04411765
postcard_width_px <- 1875
postcard_height_px <- 1275
postcard_content_width_px <- postcard_width_px - 2*ceiling(postcard_width_px*safe_margin)
postcard_content_height_px <- postcard_height_px - 2*ceiling(postcard_width_px*safe_margin)
postcard_dpi <- 300

#' Save a postcard image to a file
ggpostcard_save <- function(filename, plot, ...){
  ggplot2::ggsave(filename = filename, plot=plot, width = postcard_content_width_px/postcard_dpi, height = postcard_content_height_px/postcard_dpi, dpi = postcard_dpi, ...)
}

#' Preview the front of your postcard
#'
#' This function takes a ggplot2 output and gives a preview of how the image will look.
#' While it's totally fine to just call ggirl::ggpostcard to preview, this allows you to preview before having
#' the addresses and other details set.
#'
#' The preview will appear in either the "Viewer" pane of RStudio or in your browser, depending on if RStudio is installed or not
#'
#'
#' @param plot the plot to put on the front of the postcard
#' @param ... other options to pass to ggsave when turning the plot into an image for the front of the postcard
#' @seealso [ggpostcard()] to order the postcards
#' @examples
#' library(ggplot2)
#' library(ggirl)
#' plot <- ggplot(data.frame(x=1:10, y=runif(10)),aes(x=x,y=y))+geom_line()+geom_point()
#' ggpostcard_preview(plot)
#' @export
ggpostcard_preview <- function(plot, ...){
  temp_dir <- tempfile()
  dir.create(temp_dir)
  temp_plot_file <- file.path(temp_dir, "plot.png")
  temp_css_file <- file.path(temp_dir, "site.css")
  temp_html_file <- file.path(temp_dir, "index.html")
  add <- function(css,line) paste0(css,line,"\n")
  mg <- ceiling(postcard_width_px*(safe_margin-cut_margin))
  css <- "body {margin: 0;}\n\n.postcard {\n"
  css <- add(css, "box-shadow: 10px 5px 5px #404040;")
  css <- add(css, "border-color: #404040;")
  css <- add(css, "border-width: 2px;")
  css <- add(css, "border-style: solid;")
  css <- add(css, "max-width: 90%;")
  css <- add(css, "max-height: 90%;")
  css <- add(css, paste0("margin: ",mg,"px ",mg,"px ",mg,"px ",mg,"px;"))
  css <- add(css, "}")

  html <- '
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>ggpostcard preview</title>
    <link rel="stylesheet" href="site.css">
  </head>
  <body>
    <img src="plot.png" class = "postcard">
  </body>
</html>
  '

  ggpostcard_save(filename = temp_plot_file, plot = plot, ...)
  writeLines(css, temp_css_file)
  writeLines(html, temp_html_file)
  viewer <- getOption("viewer")
  if (!is.null(viewer))
    viewer(temp_html_file)
  else
    utils::browseURL(temp_html_file)
}

#' Order postcards of your ggplot!
#'
#' This function takes a ggplot2 output and will send postcards of it for you!
#' Running this function will bring you to a webpage to confirm the order and submit it.
#' _No order will be submitted until you explicitly approve it._
#'
#'
#' @param plot the plot to put on the front of the postcard
#' @param contact_email email address to send order updates
#' @param messages either a message to use with all of the recipients, or a list of messages of the same length as the list of addresses (one for each address).
#' @param send_addresses either a result of the "address()" function, or a list of results of the "address()" function. Currently only US addresses are allowed, but international postcards are coming soon!
#' @param return_address (optional) the return address for the postcard. **Must be a US address.**
#' @param ... other options to pass to ggsave when turning the plot into an image for the front of the postcard
#' @seealso [ggpostcard_preview()] to preview a plot on a postcard within R
#' @seealso [address()] to format an address for ggirl
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
#' ggpostcard(plot, contact_email,  messages = "An example postcard", send_addresses = send_address_1)
#'
#' # send the same message to multiple recipients
#' ggpostcard(plot, contact_email, messages = "An example postcard", send_addresses = list(send_address_1, send_address_2))
#'
#' # send different messages to multiple recipients, and a return address
#' ggpostcard(plot, contact_email,
#'            messages = c("message for sender 1","message for sender 2"),
#'            send_addresses = list(send_address_1, send_address_2),
#'            return_address = return_address)
#' @export
ggpostcard <- function(plot=last_plot(), contact_email, messages, send_addresses, return_address = NULL, ...){
  max_message_length <- 700

  if(any(nchar(messages) > max_message_length)){
    stop(paste0("Messages can be at most ", max_message_length," characters"))
  }

  if(!is.null(return_address) && return_address$country != "US"){
    stop("If return address is included then it must be in the United States")
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

  # just for launch! International coming soon
  address_countries <- sapply(messages_and_send_addresses, function(x) (x$send_address$country))
  if(any(address_countries != "US")){
    stop("Address list contains non-US countries (but international postcards are coming soon!)")
  }

  version <- packageDescription("ggirl", fields = "Version")
  if(is.na(version)){
    version <- "0.0.0"
  }

  server_url <- getOption("ggirl_server_url",
                          "https://skyetetra.shinyapps.io/ggirl-server")

  # in the event the server is sleeping, we need to kickstart it before doing the post
  response <- httr::GET(server_url)
  if(response$status_code != 200L){
    message("Waiting 10 seconds for ggirl server to come online")
    Sys.sleep(10)
  }

  temp_png <- tempfile(fileext = ".png")
  on.exit({file.remove(temp_png)}, add=TRUE)
  ggpostcard_save(filename = temp_png, plot=plot, ...)
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
  if(response$status_code == 403L){
    stop("Cannot connect to ggirl server. Go to https://ggirl.art/status to see latest status updates")
  }
  if(response$status_code != 201L){
    stop(httr::content(response, as="text", encoding="UTF-8"))
  }
  token <- httr::content(response, as="text", encoding="UTF-8")
  browseURL(paste0(server_url,"/postcard?token=",token))
}
