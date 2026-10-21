# Display-only hierarchy: whole-figure title; panel title; unchanged panel tags.
label_wrap_aligned <- function(width) {
  function(labels) {
    ans <- ggplot2::label_wrap_gen(width)(labels)
    lapply(ans, function(x) {
      n <- lengths(strsplit(x,"\n",fixed=TRUE))
      paste0(x, vapply(max(n)-n,function(k) paste(rep("\n",k),collapse=""),character(1)))
    })
  }
}
apply_title_hierarchy <- function(g) {
  if (!inherits(g, "gtable")) return(g)
  for (i in seq_along(g$grobs)) {
    nm <- g$layout$name[i]
    if (inherits(g$grobs[[i]], "gtable")) g$grobs[[i]] <- apply_title_hierarchy(g$grobs[[i]])
    if (!grepl("^title($|-)", nm) || !inherits(g$grobs[[i]], "titleGrob")) next
    if (nm == "title") {
      g$layout$l[i] <- 1L; g$layout$r[i] <- length(g$widths)
    } else {
      suffix <- sub("^title", "", nm)
      j <- match(paste0("panel", suffix), g$layout$name)
      if (!is.na(j)) g$layout[i,c("l","r")] <- g$layout[j,c("l","r")]
    }
    for (k in seq_along(g$grobs[[i]]$children)) {
      t <- g$grobs[[i]]$children[[k]]
      if (inherits(t,"text")) {
        t$x <- grid::unit(.5,"npc"); t$hjust <- .5
        g$grobs[[i]]$children[[k]] <- t
      }
    }
  }
  g
}
draw_title_hierarchy <- function(p) {
  g <- if (inherits(p,"patchwork")) patchwork::patchworkGrob(p) else ggplot2::ggplotGrob(p)
  grid::grid.draw(apply_title_hierarchy(g))
}
