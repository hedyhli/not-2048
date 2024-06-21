set shell := ["bash", "-c"]

love:
  love love

love-dist:
  cd love
  zip -9 -r not-2048.love ./IBM_Plex_Sans ./conf.lua ./main.lua
  mv not-2048.love ..
  cd ..
  pb -s 0x0.st not-2048.love
