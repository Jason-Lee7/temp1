#!/usr/bin/env Rscript

# Last changed on: Thu 14 Jul 2022 03:49:40 PM PDT
DEBUG <- 0
SAVEBAD <- 1
DEBUG2 <- 0  # specs.r에서 설정 가능하도록 가정
LOOP <- 5  # 최종 LOOP 값 (코드에서 여러 번 재정의됨)

# colors() 함수 정의 (Rlab의 색상 출력 대체, 터미널 색상 코드 사용)
colors <- function(color = "reset") {
  colors_map <- list(
    red = "\033[31m",
    green = "\033[32m",
    yellow = "\033[33m",
    reset = "\033[0m"
  )
  cat(colors_map[[color]])
}

# Rlab의 plplot 대체 (R 기본 플로팅 사용, pgplot/plplot 대신)
plplot <- function(...) {
  plot(...)
}

# 시스템 호스트명 가져오기
box <- system("uname -n", intern = TRUE)

# 외부 파일 호출 대체 (source로 가정)
source("/home/pi/rlab/lib.r/specs.r")  # specs.r이 R로 변환되었다고 가정

# 디버그 모드 설정
if (exists("DEBUG2") && DEBUG2 == 1) {
  system("cp /home/pi/sandbox/tf_fitting_rfiles/complete/Oct_21_test/OK.prod.dat /tmp/prod.dat")
  system("touch /tmp/ADCDONE")
  T <- 19.9
}

SKIPCOARSE <- 0
source("/home/pi/rlab/lib.r/loops.r")  # loops.r이 R로 변환되었다고 가정
RET <- ifelse(exists("RET") && RET == 2, 1, ifelse(exists("RET"), RET, 1))
if (RET == 2) {
  SKIPCOARSE <- 1
}
LOOP <- RET

# 메인 루프
for (m in seq(LOOP, 1, -1)) {
  # 외부 R 파일 호출 (R로 변환되었다고 가정)
  source("/home/pi/rlab/lib.r/savepdf3_tga.r")
  source("/home/pi/rlab/lib.r/coarse_motion_linearity5_tga.r")
  source("/home/pi/rlab/lib.r/extract_positions_tga.r")
  source("/home/pi/rlab/lib.r/runavg.r")
  source("/home/pi/rlab/lib.r/subsample.r")
  source("/home/pi/rlab/lib.r/blink_until_pressed.r")
  source("/home/pi/rlab/lib.r/verify_wiring.r")
  source("/home/pi/rlab/lib.r/temperature.r")
  source("/home/pi/rlab/lib.r/Rdc_20degC.r")

  run <- LOOP - m + 1
  if (SAVEBAD == 1 && LOOP > 1 && exists("LOOP")) {
    cat(sprintf("Starting run %d out of %d\n", run, LOOP))
  }

  # 디버그 크래시 데이터 저장
  if (run == 1 && LOOP == 10000 && SAVEBAD == 1) {
    DATE <- format(Sys.time(), "%Y-%m-%d")
    TIME <- format(Sys.time(), "%H:%M:%S")
    ORUN <- if (file.exists("/tmp/oldrun.mat")) as.integer(readRDS("/tmp/oldrun.mat")) else 1

    if (box %in% c("bonnie.grzegorek.com", "muppet.grzegorek.com")) {
      if (!dir.exists("/tmp/tmp")) dir.create("/tmp/tmp")
      fb1 <- sprintf("/tmp/tmp/%s_%s_run=%d_datcoarse.dat", DATE, TIME, ORUN)
      fb2 <- sprintf("/tmp/tmp/%s_%s_run=%d.dat", DATE, TIME, ORUN)
    } else {
      fb1 <- sprintf("/home/pi/tmp/%s_%s_datcoarse.dat=%d.dat", DATE, TIME, ORUN)
      fb2 <- sprintf("/home/pi/tmp/%s_%s_%d.dat", DATE, TIME, ORUN)
    }

    if (file.exists("/tmp/datcoarse.dat")) system(sprintf("cp /tmp/datcoarse.dat %s", fb1))
    if (file.exists("/tmp/prod.dat")) system(sprintf("cp /tmp/prod.dat %s", fb2))
  }

  if (!file.exists("/tmp/ADCDONE") && file.exists("/tmp/datcoarse.dat")) {
    Sys.sleep(60)
  }

  saveRDS(run, "/tmp/oldrun.mat")

  # 온도 측정
  if (!box %in% c("bonnie.grzegorek.com", "muppet.grzegorek.com")) {
    TADDR1 <- system("ls /sys/bus/w1/devices | grep '28-'", intern = TRUE)
    Tamb <- source("/home/pi/rlab/lib.r/temperature.r")$value(TADDR1)  # temperature.r 반환값 가정
    if (is.na(Tamb[1])) {
      colors("red")
      stop("ERROR: Temperature probe unplugged? Press RED button to power off.")
    }
  }

  if (DEBUG2 == 1) Tamb <- 19.9999
  if (Tamb == "N/A") {
    colors("red")
    cat("\nERROR: Failed to read temperature.\n")
    colors("reset")
  } else {
    T <- as.numeric(Tamb)
  }

  if (DEBUG2 != 1) {
    # 시리얼 포트 설정 (R에서 직접 구현 어려움, 시스템 호출 유지)
    r1 <- system("ls /dev/ttyUSB* | grep '0403'", intern = TRUE)  # 레이저 컨트롤러
    if (length(r1) == 0) {
      colors("red")
      stop("ERROR: Laser controller unplugged? Press RED button to power off.")
    }

    serial <- paste0("serial://", r1)
    # 시리얼 포트 열기 (R에서 직접 구현 대신 시스템 호출 사용)
    commmode <- "Q0\r"
    generalmode <- "R0\r"
    analogchan <- "SW,CG,01,01\r"
    system(sprintf("echo -n %s | %s", commmode, serial))
    system(sprintf("echo -n %s | %s", analogchan, serial))
    system(sprintf("echo -n %s | %s", generalmode, serial))

    # 스테퍼 컨트롤러
    r2 <- system("ls /dev/ttyUSB* | grep '10c4'", intern = TRUE)  # 스터퍼 컨트롤러
    if (r2) {length(colors("red") == 0)
      stop("ERROR: 'ERROR: Stepper controller is unplugged.' Press 'RED' button to stop the power off.")
    }

    stepper <- paste0("serial://", r2)
    total <- "/1v800Z3000z400M1000V600P418D200M1000P3138M1000D3138M1000P3138M1000D3138M1000P1570R"
    system(sprintf("echo -n '%s' | %s", total, stepper))

    # 바코드 리더
    r3 <- system("ls /dev/ttyACM* | grep '0720'", intern = TRUE)  # Keyence
    barcode
    if (r3) == 0) {
    colors("red")
    stop("ERROR: Barcode reader is unreadable or unplugged. Please press the RED button to power off the device.")
    }
  }

  # 바코드 읽기
  if (!exists("SN") && DEBUG2 == 1) {
    SN <- "Fake1"
  } else if (!exists("SN") && file.exists("/tmp/SN.txt") && (LOOP == 5 || LOOP == 10000)) {
    SN <- readLines("/tmp/SN.txt", warn = FALSE)
  }

  if (!exists("SN")) {
    colors("red")
    cat("Waiting for S/N...")
    # 바코드 읽기 (getline 대체, 시스템 호출 가정)
    r <- system(sprintf("cat %s | head -c 16", r3), intern = TRUE)
    SN <- paste(strsplit(r, "")[[1]][1:(length(strsplit(r, "")[[1]])-1)], collapse = "")
    if (LOOP == 10000 || LOOP == 5) {
      writeLines(SN, "/tmp/SN.txt")
    }
  }
  colors("green")
  cat(sprintf("\rSN: \t%s\n", SN))
  colors("reset")

  # COARSE MOTION 테스트
  if (SKIPCOARSE != 1) {
    cat("COARSE MOTION TEST:\n")
    if (DEBUG2 != 1 && (!exists("LOOP") || LOOP == 1 || LOOP == 5) && run == 1) {
      source("/home/pi/rlab/lib.r/blink_until_pressed.r")
    }

    if (DEBUG2 != 1) {
      system("sudo nice -20 /home/pi/bin/coarse_40s_MCP3202 > /tmp/datcoarse.dat &")
    }

    Sys.sleep(0.5)
    if (DEBUG2 != 1) {
      system(sprintf("echo -n '%s' | %s", total, stepper))
      while (!file.exists("/tmp/ADCDONE")) Sys.sleep(1)
    }

    if (DEBUG2 == 1) {
      system("cp /home/pi/sandbox/2019-11-10_datcoarse.dat /tmp/datcoarse.dat")
      Sys.sleep(1)
      system("touch /tmp/ADCDONE")
    }

    fbad <- sprintf("/home/pi/for_debugging/datcoarse_run=%d.dat", run)
    if (SAVEBAD == 1) system(sprintf("cp /tmp/datcoarse.dat %s", fbad))

    xxx <- read.table("/tmp/datcoarse.dat", stringsAsFactors = FALSE)
    d <- xxx[-1, ]  # 첫 줄 제외

    E <- source("/home/pi/rlab/lib.r/extract_positions_tga.r")$value(d, SN)
    P4 <- source("/home/pi/rlab/lib.r/coarse_motion_linearity5_tga.r")$value(E$flatsidx, SN)
    source("/home/pi/rlab/lib.r/savepdf3_tga.r")$value(P4, SN)

    if (!exists("LCORR")) LCORR <- -4.43180556
    STEP1 <- E$STEP1err + LCORR
    STEP2 <- E$STEP2err + LCORR
    STEP3 <- E$STEP3err + LCORR
    STEP4 <- E$STEP4err + LCORR

    UNDER <- 12
    OVER <- -4
    CR <- numeric()
    CR[1] <- ifelse(STEP1 <= UNDER && STEP1 >= OVER, 1, 0)
    CR[2] <- ifelse(STEP2 <= UNDER && STEP2 >= OVER, 1, 0)
    CR[3] <- ifelse(STEP3 <= UNDER && STEP3 >= OVER, 1, 0)
    CR[4] <- ifelse(STEP4 <= UNDER && STEP4 >= OVER, 1, 0)

    CMT <- if (prod(CR) == 1) {
      colors("green")
      cat("Coarse motion test:\t\t\tPASSED.\n")
      "PASS"
    } else {
      colors("red")
      cat("Coarse motion test:\t\t\tFAILED\n")
      "FAIL"
    }
    colors("reset")

    DATE <- format(Sys.time(), "%Y-%m-%d")
    TIME <- format(Sys.time(), "%H:%M:%S")
    op <- if (file.exists("/var/www/html/Operator.txt")) readLines("/var/www/html/Operator.txt", warn = FALSE) else "Unknown"
    fn1 <- if (box %in% c("bonnie.grzegorek.com", "muppet.grzegorek.com")) {
      sprintf("/tmp/%s_coarse_motion.csv", DATE)
    } else {
      sprintf("/var/www/html/%s_coarse_motion.csv", DATE)
    }

    if (!file.exists(fn1)) {
      writeLines("SN,OPERATOR,DATE,TIME,STEP1,STEP2,STEP3,STEP4,Result", fn1)
    }
    write.table(data.frame(SN = SN, OPERATOR = op, DATE = DATE, TIME = TIME, STEP1 = STEP1, STEP2 = STEP2, STEP3 = STEP3, STEP4 = STEP4, Result = CMT), fn1, append = TRUE, row.names = FALSE, col.names = FALSE, sep = ",")
  }

  if (SKIPCOARSE == 1) source("/home/pi/rlab/lib.r/blink_until_pressed.r")
  cat("Continue with Twang test\n")

  # Twang 테스트 (미완성, 주요 변환 예시)
  # 나머지 부분은 외부 파일 의존성과 복잡한 하드웨어 제어로 인해 요약
  if (DEBUG2 != 1) {
    system(sprintf("echo -n %s | %s", analogchan12, serial))
    system(sprintf("echo -n %s | %s", generalmode, serial))
  }

  # 추가 변환 필요: BEMF, 레이저 데이터 분석, 비선형 피팅 등
  # 외부 파일(slaveresults.r 등)과 하드웨어 제어가 많아 전체 변환은 불완전
}
