## FIXME: add ..coverage.., and a new way
setGeneric("stat_coverage", function(data, ...) standardGeneric("stat_coverage"))

setMethod("stat_coverage", "GRanges", function(data, ...,xlim,
                                               xlab, ylab, main,
                                               facets = NULL, 
                                               geom = NULL){


  if(is.null(geom))
    geom <- "area"
  data <- keepSeqlevels(data, unique(as.character(seqnames(data))))
  args <- list(...)
  args$facets <- facets
  args$geom <- geom
  args.aes <- parseArgsForAes(args)
  args.non <- parseArgsForNonAes(args)
  args.facets <- subsetArgsByFormals(args, facet_grid, facet_wrap)
  facet <- .buildFacetsFromArgs(data, args.facets)
  if(length(data)){
  grl <- splitByFacets(data, facets)
  if(missing(xlim))
    xlim <- c(min(start(ranges(data))),
              max(end(ranges(data))))
  if(!length(facets))
    facets <- as.formula(~seqnames)
  facets <- strip_formula_dots(facets)
  allvars <- all.vars(as.formula(facets))
  allvars.extra <- allvars[!allvars %in% c(".", "seqnames", "strand")]
  lst <- lapply(grl, function(dt){
    vals <- coverage(keepSeqlevels(dt, unique(as.character(seqnames(dt)))))
    if(any(is.na(seqlengths(dt)))){
      seqs <- xlim[1]:max(end(dt))
      vals <- vals[[1]][seqs]
      vals <- as.numeric(vals)                           
      vals <- c(vals, rep(0, xlim[2]-max(end(dt))))
      seqs <- xlim[1]:xlim[2]
    }else{
      seqs <- xlim[1]:xlim[2]
      vals <- vals[[1]][seqs]
      vals <- as.numeric(vals)                           
    }
    if(geom == "area" | geom == "polygon"){
      seqs <- c(seqs, rev(seqs))
      vals <- c(vals, rep(0, length(vals)))
      ## .df <- data.frame(x = seqs, y = vals)
      ## qplot(data = .df, x = x, y = y, geom = "polygon")

    }
    if(length(unique(values(dt)$.id.name))){                
      res <- data.frame(coverage = vals, seqs = seqs,
                        seqnames =
                        as.character(seqnames(dt))[1],
                        .id.name = unique(values(dt)$.id.name))
    }else{
      if("strand" %in% all.vars(facets))
        res <- data.frame(coverage = vals, seqs = seqs,
                          seqnames =
                          as.character(seqnames(dt))[1],
                          strand = unique(as.character(strand(dt))))
      else
        res <- data.frame(coverage = vals, seqs = seqs,
                          seqnames =
                          as.character(seqnames(dt))[1])

    }
    res[,allvars.extra] <- rep(unique(values(dt)[, allvars.extra]),
                               nrow(res))
    res
  })
  res <- do.call(rbind, lst)
  if(!"y"  %in% names(args.aes))
    args.aes$y <- as.name("coverage")
  
  if(!"x"  %in% names(args.aes))
    args.aes$x <- as.name("seqs")

  aes <- do.call(aes, args.aes)
  if(geom  == "area" | geom == "polygon")
    args.non$geom <- "polygon"
  args.res <- c(list(data = res),
                list(aes),
                args.non)
  p <- do.call(stat_identity, args.res)
}else{
  p <- NULL
}

  p <- .changeStrandColor(p, args.aes)
  p <- c(list(p) , list(facet))
  if(missing(xlab)) 
    xlab <- ""
  p <- c(p, list(ggplot2::xlab(xlab)))


  if(!missing(ylab))
    p <- c(p, list(ggplot2::ylab(ylab)))
  else
    p <- c(p, list(ggplot2::ylab("Coverage")))
  if(!missing(main))
    p <- c(p, list(labs(title = main)))

  p <- setStat(p)    
  p
})


setMethod("stat_coverage", "GRangesList", function(data, ..., xlim,
                                                   xlab, ylab, main,
                                                   facets = NULL, 
                                               geom = NULL){
  args <- list(...)
  args$facets <- facets
  args.aes <- parseArgsForAes(args)
  if(!"y" %in% names(args.aes))
    args.aes$y <- as.name("coverage")
  args.non <- parseArgsForNonAes(args)
  if(!is.null(geom))
    args.non$geom <- geom
  aes.res <- do.call(aes, args.aes)
  gr <- flatGrl(data)
  args.non$data <- gr
  p <- do.call(stat_coverage, c(list(aes.res), args.non))
  if(!missing(xlab))
    p <- c(p, list(ggplot2::xlab(xlab)))
  else
    p <- c(p, list(ggplot2::xlab("Genomic Coordinates")))

  if(!missing(ylab))
    p <- c(p, list(ggplot2::ylab(ylab)))
  else
    p <- c(p, list(ggplot2::ylab("Coverage")))
  if(!missing(main))
    p <- c(p, list(labs(title = main)))

  p <- setStat(p)    
  p
})


setMethod("stat_coverage", "BamFile", function(data, ..., maxBinSize = 2^14, xlim,
                                               which,
                                               xlab, ylab, main,
                                               facets = NULL, 
                                               geom = NULL,
                                               method = c("estimate", "raw"),
                                               space.skip = 0.1,
                                               coord = c("linear", "genome")){

  coord <- match.arg(coord)  
  if(missing(which)){
      ## stop("missing which is not supported yet")
      p <- c(list(geom_blank()),list(ggplot2::ylim(c(0, 1))),
             list(ggplot2::xlim(c(0, 1))))
      return(p)
  }else{

      if(is(which, "GRanges")){
          seq.nm <- unique(as.character(seqnames(which)))
      } else if(is(which, "character")){
          seq.nm <- which
      }else{
          stop("which must be missing, GRanges or character(for seqnames)")
      }
  }

  ## if(missing(which)){
  ##   seq.nm <- names(scanBamHeader(data)[[1]])[1]
  ## }

  args <- list(...)
  args$facets <- facets
  args.aes <- parseArgsForAes(args)
  if(!"y" %in% names(args.aes)){
    args.aes$y <- as.name("score")
  }else{
    if(as.character(args.aes$y) == "coverage")
      args.aes$y <- as.name("score")
  }
  if(!"x" %in% names(args.aes)){
    args.aes$x <- as.name("midpoint")
  }
  args.non <- parseArgsForNonAes(args)
  args.non <- args.non[!names(args.non) %in% c("method", "maxBinSize", "data", "which")]
  
  
  if(is.null(geom))
    geom <- "line"
  args.non$geom <- geom
  method <- match.arg(method)

  res <- switch(method,
                estimate = {
                  message("Estimating coverage...")
                  res <- estimateCoverage(data, maxBinSize = maxBinSize)
                  if(!missing(which) && is(which, "GRanges"))
                    res <- subsetByOverlaps(res, which)
                  res
                },
                raw = {
                  if(missing(which))
                    stop("method 'raw' require which argument")
                  message("Parsing raw coverage...")
                  res <- crunch(data, which = which)
                })
  res.ori <- res
  
  if(method == "estimate"){
  message("Constructing graphics...")
  res <- res[seqnames(res) %in% seq.nm]

  args.facets <- subsetArgsByFormals(args, facet_grid, facet_wrap)
  facet <- .buildFacetsFromArgs(res, args.facets)
  res <- keepSeqlevels(res, unique(as.character(seqnames(res))))


  if(coord == "genome"){
    res <- transformToGenome(res, space.skip = space.skip)
    res.ori <- res <- biovizBase:::rescaleGr(res)
  }
  
  if(geom == "area"){
    grl <- splitByFacets(res, facets)
    res <- endoapply(grl, function(gr){
      gr <- sort(gr)
      .gr1 <- gr[1]
      values(.gr1)$score <- 0
      .grn <- gr[length(gr)]
      values(.grn)$score <- 0
      c(gr,.gr1, .grn) 
    })
    res <- unlist(res)
  }
  res <- mold(res)
  aes.res <- do.call(aes, args.aes)
  args.res <- c(list(data = res),
                list(aes.res),
                args.non)

  p <- c(list(do.call(stat_identity, args.res)), list(facet))
}
  if(method == "raw"){
    p <- stat_coverage(res, ..., geom = geom, facets = facets)
  }

  if(!missing(xlab))
    p <- c(p, list(ggplot2::xlab(xlab)))
  else
    p <- c(p, list(ggplot2::xlab("Genomic Coordinates")))

  if(!missing(ylab))
    p <- c(p, list(ggplot2::ylab(ylab)))
  else
    p <- c(p, list(ggplot2::ylab("Coverage")))
  if(!missing(main))
    p <- c(p, list(labs(title = main)))

  if(is_coord_genome(res.ori)){
    ss <- getXScale(res.ori)
    p <- c(p, list(scale_x_continuous(breaks = ss$breaks,
                                labels = ss$labels)))
  }
  if(coord == "genome"){
    facet <- facet_null()
    p <- c(p, list(facet))
  }
  p <- setStat(p)  
  p
  
})
