require_relative 'all_avatars_names'

module WellFormedAvatarName # mix-in

  module_function

  def well_formed_avatar_name?(avatar_name)
    all_avatars_names.include?(avatar_name)
  end

  include AllAvatarsNames

end
