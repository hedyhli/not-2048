set shell := ["bash", "-c"]

love:
  love love

love-dist:
  cd love && zip -9 -r not-2048.love ./IBM_Plex_Sans ./conf.lua ./main.lua
  mv love/not-2048.love .
  pb -s 0x0.st not-2048.love
