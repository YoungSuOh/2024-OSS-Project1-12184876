#!/bin/bash


# 인자 개수 확인
if [ "$#" -ne 3 ]; then
    echo "usage: $0 file1 file2 file3"
    exit 1
fi

# 스크립트 시작시 인사말 출력
echo "************OSS1 - Project1************"
echo "* StudentID : 12184876 *"
echo "* Name : 오영수 *"
echo "*******************************************"

# 메뉴 출력 함수
function print_menu() {
    echo "[MENU]"
    echo "1. Get the data of Heung-Min Son's Current Club, Appearances, Goals, Assists in players.csv"
    echo "2. Get the team data to enter a league position in teams.csv"
    echo "3. Get the Top-3 Attendance matches in matches.csv"
    echo "4. Get the team's league position and team's top scorer in teams.csv & players.csv"
    echo "5. Get the modified format of date_GMT in matches.csv"
    echo "6. Get the data of the winning team by the largest difference on home stadium in teams.csv & matches.csv"
    echo "7. Exit"
}

# 파일 이름 변수 할당
TEAMS_FILE=$1
PLAYERS_FILE=$2
MATCHES_FILE=$3


function son_data() {
    echo -n "Do you want to get the Heung-Min Son's data? (y/n)"
    read answer
    if [[ $answer == "y" ]]; then
        awk -F, '$1=="Heung-Min Son" {
            print "Team:" $4 ", Appearance:" $6 ", Goal:" $7 ", Assist:" $8
        }' "$PLAYERS_FILE"
    fi
}

function team_data() {
    echo -n "What do you want to get the team data of league_position[1~20]: "
    read position

    # teams.csv에서 해당 리그 포지션의 팀 데이터 찾기
    awk -F, -v pos="$position" '$6 == pos {
        wins=$2; draws=$3; losses=$4
        total_matches=wins+draws+losses
        if (total_matches > 0) {
            win_rate=wins/total_matches
        } else {
            win_rate=0  # 경기 수가 0이면 승률을 0으로 처리
        }
        printf "%s %s %.6f\n", $6, $1, win_rate
    }' "$TEAMS_FILE"
}

function top_attendance() {
    echo -n "Do you want to know Top-3 attendance data and average attendance? (y/n): "
    read answer
    if [[ $answer == "y" ]]; then
        echo -e "***Top-3 Attendance Match***\n"
        # matches.csv 파일에서 출석률이 높은 상위 3경기를 정렬하여 출력
        awk -F, 'NR > 1 {print $2, $0}' $MATCHES_FILE | sort -nr -k1,1 | cut -d ' ' -f2- | head -3 |
            awk -F, '{printf "%s vs %s (%s)\n%s %s\n\n", $3, $4, $1, $2, $7}'
    fi
}

function team_and_scorer() {
    echo -n "Do you want to get each team's ranking and the highest-scoring player? (y/n) : "
    read answer
    if [[ $answer == "y" ]]; then
        echo -e "\n"
        sort -t, -k6,6n $TEAMS_FILE | while IFS=, read -r common_name wins draws losses points_per_game league_position cards_total shots fouls; do
            if [[ "$league_position" != "league_position" ]]; then # 헤더 제외
                # 해당 팀의 최고 득점자의 골 수 찾기
                max_goals=$(awk -F, -v team="$common_name" '$4==team {print $7}' $PLAYERS_FILE | sort -nr | head -1)

                # 최대 골 수를 기록한 모든 선수들의 이름과 골 수를 하나의 문자열로 결합
                top_scorers=$(awk -F, -v team="$common_name" -v max_goals="$max_goals" '$4==team && $7==max_goals {printf "%s %s ", $1, $7}' $PLAYERS_FILE)

                # 결과 출력
                echo -e "$league_position $common_name\n$top_scorers\n"
            fi
        done
    fi
}

function modify_date() {
    echo -n "Do you want to modify the format of date? (y/n) : "
    read answer
    if [[ $answer == "y" ]]; then
        awk -F, 'NR > 1 && NR <= 11 { print $1 }' matches.csv | 
awk -F'[/ ]' '{ print $1 "/" $2 "/" $3 " " $4 }' | 
sed -e 's/Jan/01/' -e 's/Feb/02/' -e 's/Mar/03/' \
    -e 's/Apr/04/' -e 's/May/05/' -e 's/Jun/06/' \
    -e 's/Jul/07/' -e 's/Aug/08/' -e 's/Sep/09/' \
    -e 's/Oct/10/' -e 's/Nov/11/' -e 's/Dec/12/' | 
awk -F'[/ ]' '{ printf $1 "/" $3 "/" $2 " " $4 "\n" }'
    fi
}



function largest_win() {
    teams=$(awk -F, 'NR > 1 {printf "%2d) %-35s\n", NR-1, $1}' $TEAMS_FILE)
    echo "$teams" | awk '{
        lines[NR] = $0;                 # 각 라인을 배열에 저장
    }
    END {
        half = int((NR + 1) / 2);       # 배열의 절반 계산
        for (i = 1; i <= half; i++) {
            if (i + half <= NR) {
                printf "%-40s %s\n", lines[i], lines[i + half];  # 첫 절반과 두 번째 절반 출력
            } else {
                printf "%-40s\n", lines[i];  # 남은 팀 출력 (홀수 경우)
            }
        }
    }'

    echo -n "Enter your team number: "
    read team_number
    team_name=$(awk -F, -v num="$team_number" 'NR == num + 1 {print $1}' $TEAMS_FILE)

    largest_wins=$(awk -F, -v team="$team_name" '
    $3 == team {
        goal_diff = $5 - $6
        print goal_diff "," $0
    }' $MATCHES_FILE | sort -t, -nr -k1,1)

    largest_diff=$(echo "$largest_wins" | head -1 | cut -d, -f1)
    awk -F '[,/]' -v diff="$largest_diff" '$1 == diff {
        split($4, date_parts, " ");  # 날짜를 '/'으로 분리
        month = date_parts[1];
        time = date_parts[2];
        printf "\n%s %02d %s - %s\n", month, $3, $2, time;
        printf "%s %d vs %d %s\n\n", $6, $8, $9, $7;
    }' <<<"$largest_wins"
}



# 메인 실행 루프
while true; do
    print_menu
    echo -n "Enter your CHOICE (1~7) : "
    read choice
    case $choice in
    1) son_data ;;
    2) team_data ;;
    3) top_attendance ;;
    4) team_and_scorer ;;
    5) modify_date ;;
    6) largest_win ;;
    7)
        echo "Bye!"
        break	
        ;;
    *) echo continue ;;
    esac
done
