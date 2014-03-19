FactoryGirl.define do
  factory :user do
    sequence(:username) { |n| "testuser#{n}" }
    email { "#{username}@example.com.xx" }
    password "00secret"
    locale 'en-US'
    name { "#{username} Codeberg" }

    # Child of :user factory, since it's in the `factory :user` block
    factory :admin do
      admin true
    end

    factory :teacher do
      user_type User::TYPE_TEACHER
    end
  end

  factory :section do
    sequence(:name) { |n| "Section #{n}"}
    user
  end

  factory :game do
    sequence(:name) { |n| "game#{n}.com"}
    app "maze"
  end

  factory :level do
    sequence(:name) { |n| "Level #{n}" }
    sequence(:level_num) {|n| "1_2_#{n}" }
    
    game
    
    trait :blockly do
      game {create(:game, app: "maze")}
    end
  
    trait :unplugged do
      game {create(:game, app: "unplug")}
    end
  end

  factory :script do
  end
  
  factory :script_level do
    script
    level
    chapter 1
  end
  
  factory :callout do
    sequence(:element_id) { |n| "#pageElement#{n}" }
    text 'Hey check this element out!'
    script_level
  end

  factory :activity do
    level
    user
  end

  factory :concept do
    sequence(:name) { |n| "Algorithm #{n}" }
  end

  factory :video do
    sequence(:key) { |n| "concept_#{n}" }
    youtube_code 'Bogus text'
  end

  factory :prize do
    prize_provider
    sequence(:code) { |n| "prize_code_#{n}" }
  end

  factory :prize_provider do
  end
end
