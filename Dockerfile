FROM python:2.7
LABEL maintainer="Hossam Hammady <github@hammady.net>"

RUN apt-get update && \
    apt-get install -y inkscape && \
    pip install --upgrade pip

WORKDIR /home

COPY requirements.txt /home/
RUN pip install -r requirements.txt

COPY . /home

# CMD ["./svg2png.sh", "800", "10", "/svg", "./output/images"]
# CMD ["python", "./fix_color_mode.py", "./output/images/800"]
CMD ["python", "./main.py", \
  "--input_path", "./output/images/800", \
  "--output_path", "./output", \
  "--separator1_path", "./separator1.png", \
  "--separator3_path", "./separator3.png", \
  # "--start_page", "10", \
  # "--start_sura", "2", \
  # "--start_aya", "61", \
  # "--end_page", "20", \
  "--count_method", "basry"]
