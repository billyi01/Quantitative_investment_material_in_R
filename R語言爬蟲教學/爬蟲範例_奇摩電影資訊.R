# 爬取奇摩電影資訊
# 程式撰寫: 蘇彥庭
library(rvest)
library(dplyr)
library(xlsx)
library(RMySQL)

# 建立儲存表
movieData <- NULL  

# 下載上映中及即將上映的電影資訊
# intheaters:上映中
# comingsoon:即將上映
for(webPageName in c("intheaters","comingsoon")){
  
  # 設定起始值
  ix <- 1            
  while(T){
    
    cat(paste0("正在爬取 ",webPageName," 第 ",ix," 個頁面\n"))
    
    # 網址
    url <- paste0("https://movies.yahoo.com.tw/movie_",webPageName,".html?page=",ix)
    
    # 電影中文名稱
    movieName <- read_html(url, encoding = "utf-8") %>%
      html_nodes(css=".release_movie_name > .gabtn") %>%  
      html_text() %>%
      gsub("\\s","",.)
    
    if(length(movieName)==0){
      cat(paste0("爬取結束\n"))
      break
    }
    
    # 電影英文名稱
    movieEngName <- read_html(url, encoding = "utf-8") %>%
      html_nodes(css=".en .gabtn") %>%  
      html_text() %>%
      gsub("\\s","",.)
    
    # 電影上映日期
    movieReleasedDate <- read_html(url, encoding = "utf-8") %>%
      html_nodes(css=".release_movie_time") %>%  
      html_text() %>%
      gsub("上映日期 ： ","",.)
    
    # 電影詳細內容連結
    movieLink <- read_html(url, encoding = "utf-8") %>%
      html_nodes(css=".release_text a") %>%  
      html_attr("href")
    
    # 電影圖片連結
    imgLink <- read_html(url, encoding = "utf-8") %>%
      html_nodes(css="#content_l img") %>%  
      html_attr("src")
    
    # 儲存資訊
    movieData <- bind_rows(movieData, 
                           tibble(webPageName, movieName, movieEngName, movieReleasedDate, movieLink, imgLink))
    
    # 進入下一次迴圈
    ix <- ix+1
    
    # 暫緩
    Sys.sleep(1)
  }
}

# 對電影名稱做轉換成big5，避免待會儲存檔名時報錯
movieData$movieGraphName <- iconv(movieData$movieName, from="utf8", to="big5", sub="byte") %>%
  gsub("<","", .) %>%
  gsub(">","", .) %>%
  gsub("/","", .)

# 建立儲存表
movieData$movieLength <- rep(NA, nrow(movieData))       # 電影片長
movieData$movieDirector <- rep(NA, nrow(movieData))     # 電影導演
movieData$movieActor <- rep(NA, nrow(movieData))        # 電影演員
movieData$movieAbstract <- rep(NA, nrow(movieData))     # 電影摘要
movieData$movieType1 <- rep(NA, nrow(movieData))        # 電影類型1
movieData$movieType2 <- rep(NA, nrow(movieData))        # 電影類型2
movieData$movieType3 <- rep(NA, nrow(movieData))        # 電影類型3
movieData$movieType4 <- rep(NA, nrow(movieData))        # 電影類型4
movieData$movieType5 <- rep(NA, nrow(movieData))        # 電影類型5
movieData$moviePreviewLink <- rep(NA, nrow(movieData))  # 電影連結

# 下載電影圖片及詳細資料
for(ix in 1:nrow(movieData)){
  
  # 下載電影圖片
  cat(paste0("正在下載第",ix,"個電影海報圖，進度：",ix," / ",nrow(movieData),"\n"))
  download.file(movieData$imgLink[ix],
                destfile=paste0("./movieData/graph/",movieData$movieGraphName[ix],".jpg"),
                mode="wb")
  
  # 下載電影詳細資料
  url <- movieData$movieLink[ix]
  movieDetail <- read_html(url, encoding = "utf-8") %>%
    html_nodes(css=".gray_infobox_inner , .movie_intro_list , span:nth-child(6)") %>%  
    html_text()
  
  # 電影片長
  movieData$movieLength[ix] <- movieDetail[1] %>% gsub("片　　長：", "", .)
  
  # 電影導演
  movieData$movieDirector[ix] <- movieDetail[2] %>% gsub(" ", "", .) %>% gsub("\n", "", .)
  
  # 電影演員
  movieData$movieActor[ix] <- movieDetail[3] %>% gsub(" ", "", .) %>% gsub("\n", "", .)
  
  # 電影摘要
  movieData$movieAbstract[ix] <- movieDetail[4] %>% gsub("詳全文", "", .)
  
  # 電影類型
  movieType <- read_html(url, encoding = "utf-8") %>%
    html_nodes(css=".level_name .gabtn") %>%  
    html_text() %>% 
    gsub(" ", "", .) %>% 
    gsub("\n", "", .)
  movieData$movieType1[ix] <- movieType[1]
  movieData$movieType2[ix] <- movieType[2]
  movieData$movieType3[ix] <- movieType[3]
  movieData$movieType4[ix] <- movieType[4]
  movieData$movieType5[ix] <- movieType[5]
  
  # 電影預告連結
  moviePreviewLink <- read_html(url, encoding= "utf-8") %>%
    html_nodes(css=".select+ li .gabtn") %>%  
    html_attr("href") %>%
    strsplit("\\?") %>%
    unlist() %>%
    .[1] %>%
    paste0("?format=embed")
  movieData$moviePreviewLink[ix] <- moviePreviewLink
}

# 寫出檔案
write.xlsx(movieData, file=paste0("./movieData/電影資訊.xlsx"))

# 摘要資料清理
movieData$movieAbstract <- gsub("\n","",movieData$movieAbstract)
movieData$movieAbstract <- gsub("\r","",movieData$movieAbstract)
movieData$movieAbstract <- gsub(" ","",movieData$movieAbstract)
movieData$movieAbstract <- gsub("<U+00A0>","",movieData$movieAbstract)

# 資料連結整理
movieData$moviePreviewLink[which(movieData$moviePreviewLink=="?format=embed")] <- NA




