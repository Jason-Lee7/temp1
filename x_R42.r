# This script has been converted from an rlab script to standard R
# for compatibility with R 4.2.

# Helper function mimicking `reads` from the original script.
read_data <- function(path_or_cmd) {
  if (startsWith(path_or_cmd, "|")) {
    cmd <- substring(path_or_cmd, 2)
    result <- system(cmd, intern = TRUE)
    paste(result, collapse = "\n")
  } else if (file.exists(path_or_cmd)) {
    paste(readLines(path_or_cmd, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
}

last_rev <- "Sun Aug 11 21:24:56 KST 2024"
cat("******************************\n")
cat("TGA software last modified on ", last_rev, "\n", sep = "")

DATE <- format(Sys.time(), "%Y-%m-%d")
TIME <- format(Sys.time(), "%H:%M:%S")

op <- read_data("/var/www/html/Operator.txt")
_IP <- read_data("|hostname -I")

if (nzchar(_IP)) {
  myipaddr <- strsplit(_IP, " ")[[1]]
} else {
  myipaddr <- character()
}

# Filter out link-local and IPv6 addresses starting with 2601:
b <- myipaddr[!startsWith(myipaddr, "169.254.")]
myipaddr <- b[!startsWith(b, "2601:")]

cat(sprintf("Today is: \t%s\n", DATE))
cat(sprintf("Time is: \t%s\n", TIME))
cat(sprintf("Current operator name is:\t%s\n", op))
if (length(myipaddr) > 0) {
  cat(sprintf("IP address is: \t%s\n", myipaddr[1]))
}
cat("******************************\n\n")

system("sudo echo 18 > /sys/class/gpio/export 2>/dev/null")
system("sudo echo 17 > /sys/class/gpio/export 2>/dev/null")

system("scp -q /home/pi/rlab/lib.r/specs.r  slave:/tmp ")

source("blink_until_pressed.R")
while (TRUE) {
  blink_until_pressed()
  source("stepper_twang_rev5.10.no_comments.R")
}
