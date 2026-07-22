# Public-layer centre anonymisation helpers.
#
# Original centre codes remain in controlled analysis inputs and model objects.
# These functions are used only while constructing manuscript-facing and
# publicly distributed assets.

build_public_centre_map <- function(x, expected_n = 30L) {
  codes <- trimws(as.character(x))
  codes <- codes[!is.na(codes) & nzchar(codes)]
  codes <- sort(unique(codes), method = "radix")
  if (length(codes) != expected_n) {
    stop("Expected ", expected_n, " distinct centre codes, found ", length(codes))
  }
  data.frame(
    original_center = codes,
    public_center = sprintf("Centre %02d", seq_along(codes)),
    stringsAsFactors = FALSE
  )
}

anonymise_public_centre_values <- function(x, centre_map) {
  values <- as.character(x)
  idx <- match(values, centre_map$original_center)
  unmatched <- !is.na(values) & nzchar(values) & is.na(idx)
  if (any(unmatched)) {
    stop(
      "Unmapped centre code(s): ",
      paste(sort(unique(values[unmatched]), method = "radix"), collapse = ", ")
    )
  }
  values[!is.na(idx)] <- centre_map$public_center[idx[!is.na(idx)]]
  values
}

anonymise_public_centre_tokens <- function(x, centre_map, prefix = "center=") {
  values <- as.character(x)
  is_token <- !is.na(values) & startsWith(values, prefix)
  if (!any(is_token)) return(values)
  codes <- substring(values[is_token], nchar(prefix) + 1L)
  mapped <- anonymise_public_centre_values(codes, centre_map)
  values[is_token] <- paste0(prefix, mapped)
  values
}

anonymise_public_centre_frame <- function(x, centre_map) {
  out <- x
  if ("center" %in% names(out)) {
    out$center <- anonymise_public_centre_values(out$center, centre_map)
  }
  if ("centre" %in% names(out)) {
    out$centre <- anonymise_public_centre_values(out$centre, centre_map)
  }
  if ("variable" %in% names(out)) {
    out$variable <- anonymise_public_centre_tokens(out$variable, centre_map)
  }
  out
}

assert_public_centre_labels <- function(x, centre_map) {
  public_pattern <- "^Centre [0-9]{2}$"
  token_pattern <- "^center=Centre [0-9]{2}$"
  if ("center" %in% names(x)) {
    stopifnot(all(grepl(public_pattern, x$center)))
  }
  if ("centre" %in% names(x)) {
    stopifnot(all(grepl(public_pattern, x$centre)))
  }
  if ("variable" %in% names(x)) {
    centre_tokens <- x$variable[startsWith(as.character(x$variable), "center=")]
    stopifnot(all(grepl(token_pattern, centre_tokens)))
  }
  text <- unlist(lapply(x, as.character), use.names = FALSE)
  leaked <- centre_map$original_center[vapply(
    centre_map$original_center,
    function(code) any(text == code | text == paste0("center=", code), na.rm = TRUE),
    logical(1)
  )]
  if (length(leaked)) {
    stop("Original centre labels remain in public frame: ", paste(leaked, collapse = ", "))
  }
  invisible(TRUE)
}
