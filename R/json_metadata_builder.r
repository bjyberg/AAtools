collection_metadata <- function(
    folder.path,
    folder.description,
    metadata.author,
    metadata.author.email,
    keywords,
# These are shared between folder and item groups folder takes priority, so if they are assigned here, they can't be assigned in group
    source.author = NULL,
    source.author.email = NULL,
    source.license = NULL, 
    source.citation = NULL,
    source.url = NULL,
    source.doi = NULL,
    add.assets = TRUE,
    process.description = NULL,
    process.derived_from = NULL,
    process.code = NULL
    ) {
  meta.author <- .author(metadata.author, metadata.author.email)
  meta.dateCreated <- format(Sys.time(), "%Y-%m-%d")
  meta.dateModified <- format(Sys.time(), "%Y-%m-%d")
  folder.source <- .source(source.license, source.citation, source.url, source.doi)
  if (add.assets) {
    assets <- .assets()
  } else {
    assets <- NULL
  }
  process = .processing_metadata(process.derived_from,
    process.description,
    process.code
  )
  metadata <- list()
  metadata[["authors"]] <- meta.author
  metadata[["dateCreated"]] <- meta.dateCreated
  metadata[["dateModified"]] <- meta.dateModified

  source <- list()
  source[["authors"]] <- .author(source.author, source.author.email)
  source <- append(source, folder.source)

  folder.metadata <- list(
    collectionName = basename(folder.path),
    collectionPath = folder.path,
    description = folder.description,
    keywords = keywords,
    metadata = metadata,
    # metadataAuthors = meta.author,
    # dateCreated = meta.dateCreated,
    # dateModified = meta.dateModified,
    # datasetAuthors = .author(source.author, source.author.email)
    source = source,
    processing = process
  )
  out_nam <- paste0(folder.path, "/", basename(folder.path),
    "_digiAtlas-metadata.json") # THIS PART OF NAME HARDCODED TO FIND LATER
  
  jsonlite::toJSON(folder.metadata, pretty = T, auto_unbox = T) |>
    cat(file = out_nam)
  
  return(folder.metadata)
}

itemgroup_metadata <- function( # TODO: add write fn to this and catalog
  folder_metadata,
  file_list, # NOTE: File List should be relative to top-level json folder metadata
  name,
  description, #What is it /how is it different from the other groups?
  layers_fields, # should be the same across groups
  file.type,
  author.name,
  author.email,
  group.unit,
  name.format,
  name.separator = "_",
  coverage.region,
  temporal.resolution,
  temporal.start_date,
  temporal.end_date,
  source.license = NULL,
  source.citation = NULL,
  source.url = NULL,
  source.doi = NULL,
  process.derived_from = NULL,
  process.description = NULL,
  process.code = NULL,
  add.definitions = TRUE, # opens an interactive name builder, highly encouraged to define aspects of the file names
  add.assets = TRUE # open an interactive asset builder
){
  if (inherits(folder_metadata, "character")) {
    if (!file.exists(folder_metadata)) {
      stop(paste0(
        "Folder metadata must be a valid path to an existing .json metadata",
        " file, or a list object made by the Folder_metadata function."
      ))
    }
    folder_metadata <- jsonlite::fromJSON(folder_metadata)
  }
  if (!inherits(folder_metadata, "list")) {
    stop(paste0(
      "Folder metadata must be a valid path to an existing .json metadata",
      " file, or a list object made by the Folder_metadata function."
    ))
  }
  folder_metadata$metadata$dateModified <- format(Sys.time(), "%Y-%m-%d")
  base_folder <- folder_metadata$collectionName

  if (!is.null(folder_metadata$source$license)) {
    print("license provided in folder metadata. Setting itemgroup license to NULL")
    source.license <- NULL
  }
  if (!is.null(folder_metadata$source$citation)) {
    print("citation provided in folder metadata. Setting itemgroup citation to NULL")
    source.citation <- NULL
  }
  if (!is.null(folder_metadata$source$url)) {
    print("license provide in folder metadata. Setting itemgroup license to NULL")
    source.url <- NULL
  }
  if (!is.null(folder_metadata$source$doi)) {
    print("citation provided in folder metadata. Setting itemgroup citation to NULL")
    source.doi <- NULL
  }
  # if (!is.null(folder_metadata$processing$derived_from)) {
  #   print("derived_from provided in folder metadata. Setting itemgroup derived_from to NULL") # TODO: Decide if should allow both
  #   process.derived_from <- NULL
  # }
  # if (!is.null(folder_metadata$processing$description)) {
  #   print("description provided in folder metadata. Setting itemgroup description to NULL")
  #   process.description <- NULL
  # }
  # if (!is.null(folder_metadata$processing$code)) {
  #   print("code provided in folder metadata. Setting itemgroup code to NULL")
  #   process.code <- NULL
  # }
  author <- .author(author.name, author.email)
  spatial <- .spatial_coverage(file_list[1], coverage.region)
  temporal <- .temporal_coverage(temporal.resolution, temporal.start_date, temporal.end_date)
  coverage <- c(spatial, temporal)
  source <- .source(source.license, source.citation, source.url, source.doi)
  if (add.assets) {
    assets <- .assets()
  } else {
    assets <- NULL
  }
  if (!exists("group.unit")) {
    group.unit <- NULL
  }
  files <- .files(file_list, base_folder)
  nameScheme <- list(nameFormat = name.format, separator = name.separator)

  if (add.definitions) {
    definitions <- .sub_group_metadata(name.format,
      name.separator,
      files,
      group.unit)
    def_level <- menu(c("item group", "full collection"),
      title = "Do the name definitions apply to the item group or full collection?")
    if (def_level == 1) {
      group.definitions <- definitions
    }
    if (def_level == 2) {
      group.definitions <- NULL
      folder_metadata$definitions <- append(folder_metadata$definitions, definitions)
    }
  } else {
    group.definitions <- NULL
  }


  group_metadata <- list(
    name = name,
    description = description,
    author = author,
    layers = layers_fields,
    fileType = file.type,
    source = source,
    coverage = coverage,
    naming = nameScheme,
    assets = assets,
    process = list(
      derived_from = process.derived_from,
      description = process.description,
      code = process.code
    ),
    definitions = group.definitions,
    files = files
  )
  
  folder_metadata[["fileGroups"]] <- append(folder_metadata[["fileGroups"]],
    setNames(list(hold = group_metadata), name))
  
  collectionName <- basename(folder_metadata$collectionName)
  out_nam <- paste0(folder_metadata$collectionPath, "/", collectionName,
    "_digiAtlas-metadata.json") # THIS PART OF NAME HARDCODED TO FIND LATER
  jsonlite::toJSON(folder_metadata, pretty = T, auto_unbox = T) |>
    cat(file = out_nam)

  return(folder_metadata)
}

.sub_group_metadata <- function(name.format, name.separator, file_list, group.unit) {
  cat(paste("Now enter information for the parts of:", name.format, "\n"))
  name.separator <- paste0(name.separator, "|", "\\[", "|", "]", collapse = "|")
  pieces <- unlist(strsplit(name.format, name.separator))
  pieces <- gsub("\\[|\\]|\\/", "", pieces)
  name_parts <- list()
  for (i in pieces) {
    if (i == "" | is.null(i) | is.na(i) | i == " ") {
      next
    }
    def <- readline(prompt = paste0("Enter definition for ", i, ": "))
    complex <- menu(c("Yes", "No"), title = paste0("Does ", i,
      " have any sub-variables that need defined?"))
    if (complex == 1) {
      sub_list <- list()
      inherit <- menu(c("Yes", "No"),
        title = paste0("Try to inherit values from the file names?"))
      if (inherit == 1) {
        position <- match(i, pieces)
        vars <- lapply(strsplit(file_list, name.separator), `[`, position)
        unique_vars <- unique(unlist(vars))
        for (uv in unique_vars) {
          if (is.na(uv) | uv == "" | is.null(uv)) {
            include <- 2
          } else {
            uv <- gsub("[^[:alnum:][:space:]]", " ", uv)
            uv <- trimws(uv)
            include <- menu(c("Yes", "No"), title = paste0("Include: ", uv))
          }
          if (include == 1) {
            repeat {
              sub_def <- readline(prompt = paste0("Enter definition for ", uv, ": "))
              if (is.null(group.unit)) {
                add_unit <- menu(c("Yes", "No"), title = paste0("Is ", uv,
                  " associated with a unit that differs from other sub-variables?"))
                if (add_unit == 1) {
                  unit <- readline(prompt = paste0("Enter unit for ", uv, ": "))
                  sub_list[[uv]] <- list(definition = def, unit = unit)
                } else {
                  sub_list[[uv]] <- list(definition = sub_def)
                }
              } else {
                sub_list[[uv]] <- list(definition = sub_def)
              }
              print(sub_list[[uv]])
              correct <- menu(c("Yes", "No"),
                title = paste0("Is the above information correct?"))
              if (correct == 1) {
                break
              }
            }
          }
        }
        add_custom <- menu(c("Yes", "No"), title = "Add a custom sub-variable?")
        if (add_custom == 1) {
          repeat {
            name <- readline(prompt = "Enter name of sub-variable: ")
            sub_def <- readline(prompt = paste0("Enter definition for ", name, ": "))
            add_unit <- menu(c("Yes", "No"),
              title = paste0("Is ", name, " associated with a unit that differs from other sub-variables?"))
            if (add_unit == 1) {
              unit <- readline(prompt = paste0("Enter unit for ", name, ": "))
              sub_list[[name]] <- list(definition = sub_def, unit = unit)
            } else
              sub_list[[name]] <- list(definition = sub_def)
            add_another <- menu(c("Yes", "No"),
              title = "Add another custom sub-variable?")
            if (add_another == 2) {
              break
            }
          }
        }
      } else {
        sub_var_num <- 0
        repeat {
          sub_var_num <- sub_var_num + 1
          repeat {
            name <- readline(prompt = paste0("Enter name of sub-variable ",
              sub_var_num, " in ", i, ": "))
            sub_def <- readline(prompt = paste0("Enter definition for ", name, ": "))
            add_unit <- menu(c("Yes", "No"), title = paste0("Is ", name,
              " associated with a unit that differs from other sub-variables?"))
            if (add_unit == 1) {
              unit <- readline(prompt = paste0("Enter unit for ", name, ": "))
              sub_list[[name]] <- list(definition = sub_def, unit = unit)
            } else {
              sub_list[[name]] <- list(definition = sub_def)
            }
            print(sub_list[[name]])
            correct <- menu(c("Yes", "No"), title = paste0("Is this correct?"))
            if (correct == 1) {
              break
            }
          }
          another <- menu(c("Yes", "No"),
            title = paste0("Do you want to add another sub-variable to ", i, "?"))
          if (another == 2) {
            break
          }
        }
      }
      name_parts[[i]] <- list(definition = def, variables = sub_list)
    } else {
      name_parts[[i]] <- list(definition = def)
    }
  }
  add_more <- menu(c("Yes", "No"),
    title = "Do you want to add another definition?")
  if (add_more == 1) {
    repeat{
      name <- readline(prompt = "Enter name: ")
      def <- readline(prompt = paste("Enter definition for ", name, ": "))
      add_unit <- menu(c("Yes", "No"), title = paste0("Is ", name,
        " associated with a unit that differs from other sub-variables?"))
      if (add_unit == 1) {
        unit <- readline(prompt = paste0("Enter unit for ", name, ": "))
      } else {
        unit <- NULL
      }
      name_parts[[name]] <- list(definition = def, unit = unit)
    add_another <- menu(c("Yes", "No"),
      title = "Do you want to add another definition?")
      if (add_another == 2) {
        break
      }
    }
  }
  return(name_parts)
}

.files <- function(file_list, base_path) {
  rel_file <- gsub(paste0(".*", base_path), "", file_list)
  clean_rel_file <- sub("^/|^//", "", rel_file)
}

.processing_metadata <- function(process.derived_from,
    process.description,
    process.code) {
  process <- list(
    derived_from = process.derived_from,
    description = process.description,
    code = process.code
  )
  if (all(unlist(lapply(process, is.null)))) {
    process <- NULL
  }
  return(process)
}

.author <- function(
  author.name,
  author.email
) {
  if (length(author.name) != length(author.email)) {
    length(author.email) <- length(author.name)
  }
  author_df <- data.frame(
    name = author.name,
    email = author.email
  )
  return(author_df)
}

.source <- function(
  source.license,
  source.citation,
  source.url,
  source.doi
) {
  source <- list(
    licence = source.license,
    citation = source.citation,
    sourceURL = source.url,
    doi = source.doi
  )
  if (all(unlist(lapply(source, is.null)))) {
    source <- NULL
  }
  return(source)
}

.dict <- function(
  key,
  value
  ) {
  dict <- list()
  dict[[key]] <- value
  return(dict)
}

.assets <- function() { #TODO: add custom fields?
  add_asset <- menu(c("Yes", "No"),
    title = "Add an asset (i.e., metadata, technical documentation, etc.)?")
  if (add_asset == 1) {
    assets <- list()
    repeat {
      repeat {
        asset_type <- readline(prompt = "Enter asset type: ")
        asset_name <- readline(prompt = "Enter asset name: ")
        asset_path <- readline(prompt = "Enter asset path: ")
        asset_description <- readline(prompt = "Enter asset description: ")
        asset <- .dict(asset_name,
          list(description = asset_description, path = asset_path))
        print(paste("type:", asset_type, " name:", asset_name,
          " path:", asset_path, " description:", asset_description))
        correct <- menu(c("Yes", "No"),
          title = paste("Is the above correct?"))
        if (correct == 1) {
          break
        }
      }
      assets[[asset_type]] <- append(assets[[asset_type]], asset)
      # assets <- list(assets, asset)
      add_another <- menu(c("Yes", "No"), title = "Add another asset?")
      if (add_another == 2) {
        break
      }
    }
    return(assets)
  }
}

.spatial_coverage <- function(path, coverage.region) {
  if (!file.exists(path)) {
    stop(paste("Unable to find one of the file paths. Please try again."))
  }
  try(
    {
      coverage_spat <- terra::vect(path)
    },
    silent = T
  )
  try(
    {
      coverage_spat <- terra::rast(path)
    },
    silent = T
  )
  coverage <- list()
  if (!exists("coverage_spat")) {
    coverage$region <- coverage.region
    return(coverage)
  }
  coverage$region <- coverage.region
  coverage$crs$epsg <- paste0(
    terra::crs(coverage_spat, describe = T)[c("authority", "code")],
    collapse = ":")
  coverage$crs$proj <- terra::crs(coverage_spat, proj = T)
  coverage$crs$Xresolution <- terra::res(coverage_spat)[1]
  coverage$crs$Yresolution <- terra::res(coverage_spat)[2]
  coverage$crs$resolutionUnit <- "decimal-degrees"
  coverage$extent$xmin <- terra::ext(coverage_spat)$xmin
  coverage$extent$xmax <- terra::ext(coverage_spat)$xmax
  coverage$extent$ymin <- terra::ext(coverage_spat)$ymin
  coverage$extent$ymax <- terra::ext(coverage_spat)$ymax
  return(coverage)
}

.temporal_coverage <- function(temporal.resolution, temporal.start_date, temporal.end_date) {
  coverage <- list()
  coverage$temporal$resolution <- ""
  coverage$temporal$start_date <- ""
  coverage$temporal$end_date <- ""
  return(coverage)
}


# TODO: add a spatial extent option that is not inherited
# TODO: decide if we want an indivdual author field? in itemgroup..
# TODO: Full interactive version or shiny?
# TODO: way of validating?? 
# TODO: add a name option for the folder level metadata? 
# TODO: add a try catch on save so if save error data isn't lost
# CHECK: possible folder/folder name issue not having the full path so updataing wont work. 