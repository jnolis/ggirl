# ggirl - ggplot2 in real life <img src='man/figures/logo.jpg' align="right" height="138.5" style="margin:10px;" />

This package is a platform for taking ggplot2 objects and getting real life versions of them. Tired of saving your plots with the plain 'ol `ggsave()` function? Try this package instead!

The mediums in this package that you can choose from will change over time. Currently available is...

## ggpostcard

`ggpostcard()` will take your ggplot2 object and will mail a postcard with it to the address of your choice! Great for friends and colleagues (or maybe holiday cards??). You can specify a single address or many addresses to mail to, and you can customize the message on the back. If you send postcards to many people, you can customize the backs for each recipient if you so chose. _Each postcard costs $2.50 to send._

### How to make a postcard

First, install the package with:

```r
# install.packages("remotes") # if you don't already have it
remotes::install_github("jnolis/ggirl")
```

Then create a plot you like:

```r
library(ggplot2)
plot <- ggplot(data.frame(x=1:10, y=runif(10)),aes(x=x,y=y)) + geom_line() + geom_point()
```

Now let's ship it! Specify your email address (for order updates), send and return addresses, and the message to put on the back:

```r
return_address <- address(name = "Jacqueline Nolis", address_line_1 = "111 North St",
                          city = "Seattle", state = "WA",
                          postal_code = "11111", country = "US")

contact_email <- "fakeemailforreal@gmail.com"

send_address_1 <- address(name = "Fake Personname", address_line_1 = "250 North Ave",
                          city = "Boston", state = "MA",
                          postal_code = "22222", country = "US")

message_1 <- "This plot made me think of you!"

ggpostcard(plot, contact_email, return_address, messages = message_1, send_addresses = send_address_1)
```

This will pop up a web page showing you what the order will look like. If both the front and back look good to you click the button to make the payment and submit the order! Postcards will arrive in 5-7 business days.

![The screen to review the order](man/figures/postcard-order-screen.png)