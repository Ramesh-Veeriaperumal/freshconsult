class CreateTicketFieldData < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :ticket_field_data do |t|
    	t.integer  :account_id, limit: 8
      t.integer  :flexifield_def_id, limit: 8
      t.integer  :flexifield_set_id, limit: 8
      t.string   :flexifield_set_type
      t.timestamps
      t.column   :ffs_01,  'mediumint(8) unsigned'
      t.column   :ffs_02,  'mediumint(8) unsigned'
      t.column   :ffs_03,  'mediumint(8) unsigned'
      t.column   :ffs_04,  'mediumint(8) unsigned'
      t.column   :ffs_05,  'mediumint(8) unsigned'
      t.column   :ffs_06,  'mediumint(8) unsigned'
      t.column   :ffs_07,  'mediumint(8) unsigned'
      t.column   :ffs_08,  'mediumint(8) unsigned'
      t.column   :ffs_09,  'mediumint(8) unsigned'
      t.column   :ffs_10,  'mediumint(8) unsigned'
      t.column   :ffs_11,  'mediumint(8) unsigned'
      t.column   :ffs_12,  'mediumint(8) unsigned'
      t.column   :ffs_13,  'mediumint(8) unsigned'
      t.column   :ffs_14,  'mediumint(8) unsigned'
      t.column   :ffs_15,  'mediumint(8) unsigned'
      t.column   :ffs_16,  'mediumint(8) unsigned'
      t.column   :ffs_17,  'mediumint(8) unsigned'
      t.column   :ffs_18,  'mediumint(8) unsigned'
      t.column   :ffs_19,  'mediumint(8) unsigned'
      t.column   :ffs_20,  'mediumint(8) unsigned'
      t.column   :ffs_21,  'mediumint(8) unsigned'
      t.column   :ffs_22,  'mediumint(8) unsigned'
      t.column   :ffs_23,  'mediumint(8) unsigned'
      t.column   :ffs_24,  'mediumint(8) unsigned'
      t.column   :ffs_25,  'mediumint(8) unsigned'
      t.column   :ffs_26,  'mediumint(8) unsigned'
      t.column   :ffs_27,  'mediumint(8) unsigned'
      t.column   :ffs_28,  'mediumint(8) unsigned'
      t.column   :ffs_29,  'mediumint(8) unsigned'
      t.column   :ffs_30,  'mediumint(8) unsigned'
      t.column   :ffs_31,  'mediumint(8) unsigned'
      t.column   :ffs_32,  'mediumint(8) unsigned'
      t.column   :ffs_33,  'mediumint(8) unsigned'
      t.column   :ffs_34,  'mediumint(8) unsigned'
      t.column   :ffs_35,  'mediumint(8) unsigned'
      t.column   :ffs_36,  'mediumint(8) unsigned'
      t.column   :ffs_37,  'mediumint(8) unsigned'
      t.column   :ffs_38,  'mediumint(8) unsigned'
      t.column   :ffs_39,  'mediumint(8) unsigned'
      t.column   :ffs_40,  'mediumint(8) unsigned'
      t.column   :ffs_41,  'mediumint(8) unsigned'
      t.column   :ffs_42,  'mediumint(8) unsigned'
      t.column   :ffs_43,  'mediumint(8) unsigned'
      t.column   :ffs_44,  'mediumint(8) unsigned'
      t.column   :ffs_45,  'mediumint(8) unsigned'
      t.column   :ffs_46,  'mediumint(8) unsigned'
      t.column   :ffs_47,  'mediumint(8) unsigned'
      t.column   :ffs_48,  'mediumint(8) unsigned'
      t.column   :ffs_49,  'mediumint(8) unsigned'
      t.column   :ffs_50,  'mediumint(8) unsigned'
      t.column   :ffs_51,  'mediumint(8) unsigned'
      t.column   :ffs_52,  'mediumint(8) unsigned'
      t.column   :ffs_53,  'mediumint(8) unsigned'
      t.column   :ffs_54,  'mediumint(8) unsigned'
      t.column   :ffs_55,  'mediumint(8) unsigned'
      t.column   :ffs_56,  'mediumint(8) unsigned'
      t.column   :ffs_57,  'mediumint(8) unsigned'
      t.column   :ffs_58,  'mediumint(8) unsigned'
      t.column   :ffs_59,  'mediumint(8) unsigned'
      t.column   :ffs_60,  'mediumint(8) unsigned'
      t.column   :ffs_61,  'mediumint(8) unsigned'
      t.column   :ffs_62,  'mediumint(8) unsigned'
      t.column   :ffs_63,  'mediumint(8) unsigned'
      t.column   :ffs_64,  'mediumint(8) unsigned'
      t.column   :ffs_65,  'mediumint(8) unsigned'
      t.column   :ffs_66,  'mediumint(8) unsigned'
      t.column   :ffs_67,  'mediumint(8) unsigned'
      t.column   :ffs_68,  'mediumint(8) unsigned'
      t.column   :ffs_69,  'mediumint(8) unsigned'
      t.column   :ffs_70,  'mediumint(8) unsigned'
      t.column   :ffs_71,  'mediumint(8) unsigned'
      t.column   :ffs_72,  'mediumint(8) unsigned'
      t.column   :ffs_73,  'mediumint(8) unsigned'
      t.column   :ffs_74,  'mediumint(8) unsigned'
      t.column   :ffs_75,  'mediumint(8) unsigned'
      t.column   :ffs_76,  'mediumint(8) unsigned'
      t.column   :ffs_77,  'mediumint(8) unsigned'
      t.column   :ffs_78,  'mediumint(8) unsigned'
      t.column   :ffs_79,  'mediumint(8) unsigned'
      t.column   :ffs_80,  'mediumint(8) unsigned'
      t.column   :ffs_81,  'mediumint(8) unsigned'
      t.column   :ffs_82,  'mediumint(8) unsigned'
      t.column   :ffs_83,  'mediumint(8) unsigned'
      t.column   :ffs_84,  'mediumint(8) unsigned'
      t.column   :ffs_85,  'mediumint(8) unsigned'
      t.column   :ffs_86,  'mediumint(8) unsigned'
      t.column   :ffs_87,  'mediumint(8) unsigned'
      t.column   :ffs_88,  'mediumint(8) unsigned'
      t.column   :ffs_89,  'mediumint(8) unsigned'
      t.column   :ffs_90,  'mediumint(8) unsigned'
      t.column   :ffs_91,  'mediumint(8) unsigned'
      t.column   :ffs_92,  'mediumint(8) unsigned'
      t.column   :ffs_93,  'mediumint(8) unsigned'
      t.column   :ffs_94,  'mediumint(8) unsigned'
      t.column   :ffs_95,  'mediumint(8) unsigned'
      t.column   :ffs_96,  'mediumint(8) unsigned'
      t.column   :ffs_97,  'mediumint(8) unsigned'
      t.column   :ffs_98,  'mediumint(8) unsigned'
      t.column   :ffs_99,  'mediumint(8) unsigned'
      t.column   :ffs_100, 'mediumint(8) unsigned'
      t.column   :ffs_101, 'mediumint(8) unsigned'
      t.column   :ffs_102, 'mediumint(8) unsigned'
      t.column   :ffs_103, 'mediumint(8) unsigned'
      t.column   :ffs_104, 'mediumint(8) unsigned'
      t.column   :ffs_105, 'mediumint(8) unsigned'
      t.column   :ffs_106, 'mediumint(8) unsigned'
      t.column   :ffs_107, 'mediumint(8) unsigned'
      t.column   :ffs_108, 'mediumint(8) unsigned'
      t.column   :ffs_109, 'mediumint(8) unsigned'
      t.column   :ffs_110, 'mediumint(8) unsigned'
      t.column   :ffs_111, 'mediumint(8) unsigned'
      t.column   :ffs_112, 'mediumint(8) unsigned'
      t.column   :ffs_113, 'mediumint(8) unsigned'
      t.column   :ffs_114, 'mediumint(8) unsigned'
      t.column   :ffs_115, 'mediumint(8) unsigned'
      t.column   :ffs_116, 'mediumint(8) unsigned'
      t.column   :ffs_117, 'mediumint(8) unsigned'
      t.column   :ffs_118, 'mediumint(8) unsigned'
      t.column   :ffs_119, 'mediumint(8) unsigned'
      t.column   :ffs_120, 'mediumint(8) unsigned'
      t.column   :ffs_121, 'mediumint(8) unsigned'
      t.column   :ffs_122, 'mediumint(8) unsigned'
      t.column   :ffs_123, 'mediumint(8) unsigned'
      t.column   :ffs_124, 'mediumint(8) unsigned'
      t.column   :ffs_125, 'mediumint(8) unsigned'
      t.column   :ffs_126, 'mediumint(8) unsigned'
      t.column   :ffs_127, 'mediumint(8) unsigned'
      t.column   :ffs_128, 'mediumint(8) unsigned'
      t.column   :ffs_129, 'mediumint(8) unsigned'
      t.column   :ffs_130, 'mediumint(8) unsigned'
      t.column   :ffs_131, 'mediumint(8) unsigned'
      t.column   :ffs_132, 'mediumint(8) unsigned'
      t.column   :ffs_133, 'mediumint(8) unsigned'
      t.column   :ffs_134, 'mediumint(8) unsigned'
      t.column   :ffs_135, 'mediumint(8) unsigned'
      t.column   :ffs_136, 'mediumint(8) unsigned'
      t.column   :ffs_137, 'mediumint(8) unsigned'
      t.column   :ffs_138, 'mediumint(8) unsigned'
      t.column   :ffs_139, 'mediumint(8) unsigned'
      t.column   :ffs_140, 'mediumint(8) unsigned'
      t.column   :ffs_141, 'mediumint(8) unsigned'
      t.column   :ffs_142, 'mediumint(8) unsigned'
      t.column   :ffs_143, 'mediumint(8) unsigned'
      t.column   :ffs_144, 'mediumint(8) unsigned'
      t.column   :ffs_145, 'mediumint(8) unsigned'
      t.column   :ffs_146, 'mediumint(8) unsigned'
      t.column   :ffs_147, 'mediumint(8) unsigned'
      t.column   :ffs_148, 'mediumint(8) unsigned'
      t.column   :ffs_149, 'mediumint(8) unsigned'
      t.column   :ffs_150, 'mediumint(8) unsigned'
      t.column   :ffs_151, 'mediumint(8) unsigned'
      t.column   :ffs_152, 'mediumint(8) unsigned'
      t.column   :ffs_153, 'mediumint(8) unsigned'
      t.column   :ffs_154, 'mediumint(8) unsigned'
      t.column   :ffs_155, 'mediumint(8) unsigned'
      t.column   :ffs_156, 'mediumint(8) unsigned'
      t.column   :ffs_157, 'mediumint(8) unsigned'
      t.column   :ffs_158, 'mediumint(8) unsigned'
      t.column   :ffs_159, 'mediumint(8) unsigned'
      t.column   :ffs_160, 'mediumint(8) unsigned'
      t.column   :ffs_161, 'mediumint(8) unsigned'
      t.column   :ffs_162, 'mediumint(8) unsigned'
      t.column   :ffs_163, 'mediumint(8) unsigned'
      t.column   :ffs_164, 'mediumint(8) unsigned'
      t.column   :ffs_165, 'mediumint(8) unsigned'
      t.column   :ffs_166, 'mediumint(8) unsigned'
      t.column   :ffs_167, 'mediumint(8) unsigned'
      t.column   :ffs_168, 'mediumint(8) unsigned'
      t.column   :ffs_169, 'mediumint(8) unsigned'
      t.column   :ffs_170, 'mediumint(8) unsigned'
      t.column   :ffs_171, 'mediumint(8) unsigned'
      t.column   :ffs_172, 'mediumint(8) unsigned'
      t.column   :ffs_173, 'mediumint(8) unsigned'
      t.column   :ffs_174, 'mediumint(8) unsigned'
      t.column   :ffs_175, 'mediumint(8) unsigned'
      t.column   :ffs_176, 'mediumint(8) unsigned'
      t.column   :ffs_177, 'mediumint(8) unsigned'
      t.column   :ffs_178, 'mediumint(8) unsigned'
      t.column   :ffs_179, 'mediumint(8) unsigned'
      t.column   :ffs_180, 'mediumint(8) unsigned'
      t.column   :ffs_181, 'mediumint(8) unsigned'
      t.column   :ffs_182, 'mediumint(8) unsigned'
      t.column   :ffs_183, 'mediumint(8) unsigned'
      t.column   :ffs_184, 'mediumint(8) unsigned'
      t.column   :ffs_185, 'mediumint(8) unsigned'
      t.column   :ffs_186, 'mediumint(8) unsigned'
      t.column   :ffs_187, 'mediumint(8) unsigned'
      t.column   :ffs_188, 'mediumint(8) unsigned'
      t.column   :ffs_189, 'mediumint(8) unsigned'
      t.column   :ffs_190, 'mediumint(8) unsigned'
      t.column   :ffs_191, 'mediumint(8) unsigned'
      t.column   :ffs_192, 'mediumint(8) unsigned'
      t.column   :ffs_193, 'mediumint(8) unsigned'
      t.column   :ffs_194, 'mediumint(8) unsigned'
      t.column   :ffs_195, 'mediumint(8) unsigned'
      t.column   :ffs_196, 'mediumint(8) unsigned'
      t.column   :ffs_197, 'mediumint(8) unsigned'
      t.column   :ffs_198, 'mediumint(8) unsigned'
      t.column   :ffs_199, 'mediumint(8) unsigned'
      t.column   :ffs_200, 'mediumint(8) unsigned'
      t.column   :ffs_201, 'mediumint(8) unsigned'
      t.column   :ffs_202, 'mediumint(8) unsigned'
      t.column   :ffs_203, 'mediumint(8) unsigned'
      t.column   :ffs_204, 'mediumint(8) unsigned'
      t.column   :ffs_205, 'mediumint(8) unsigned'
      t.column   :ffs_206, 'mediumint(8) unsigned'
      t.column   :ffs_207, 'mediumint(8) unsigned'
      t.column   :ffs_208, 'mediumint(8) unsigned'
      t.column   :ffs_209, 'mediumint(8) unsigned'
      t.column   :ffs_210, 'mediumint(8) unsigned'
      t.column   :ffs_211, 'mediumint(8) unsigned'
      t.column   :ffs_212, 'mediumint(8) unsigned'
      t.column   :ffs_213, 'mediumint(8) unsigned'
      t.column   :ffs_214, 'mediumint(8) unsigned'
      t.column   :ffs_215, 'mediumint(8) unsigned'
      t.column   :ffs_216, 'mediumint(8) unsigned'
      t.column   :ffs_217, 'mediumint(8) unsigned'
      t.column   :ffs_218, 'mediumint(8) unsigned'
      t.column   :ffs_219, 'mediumint(8) unsigned'
      t.column   :ffs_220, 'mediumint(8) unsigned'
      t.column   :ffs_221, 'mediumint(8) unsigned'
      t.column   :ffs_222, 'mediumint(8) unsigned'
      t.column   :ffs_223, 'mediumint(8) unsigned'
      t.column   :ffs_224, 'mediumint(8) unsigned'
      t.column   :ffs_225, 'mediumint(8) unsigned'
      t.column   :ffs_226, 'mediumint(8) unsigned'
      t.column   :ffs_227, 'mediumint(8) unsigned'
      t.column   :ffs_228, 'mediumint(8) unsigned'
      t.column   :ffs_229, 'mediumint(8) unsigned'
      t.column   :ffs_230, 'mediumint(8) unsigned'
      t.column   :ffs_231, 'mediumint(8) unsigned'
      t.column   :ffs_232, 'mediumint(8) unsigned'
      t.column   :ffs_233, 'mediumint(8) unsigned'
      t.column   :ffs_234, 'mediumint(8) unsigned'
      t.column   :ffs_235, 'mediumint(8) unsigned'
      t.column   :ffs_236, 'mediumint(8) unsigned'
      t.column   :ffs_237, 'mediumint(8) unsigned'
      t.column   :ffs_238, 'mediumint(8) unsigned'
      t.column   :ffs_239, 'mediumint(8) unsigned'
      t.column   :ffs_240, 'mediumint(8) unsigned'
      t.column   :ffs_241, 'mediumint(8) unsigned'
      t.column   :ffs_242, 'mediumint(8) unsigned'
      t.column   :ffs_243, 'mediumint(8) unsigned'
      t.column   :ffs_244, 'mediumint(8) unsigned'
      t.column   :ffs_245, 'mediumint(8) unsigned'
      t.column   :ffs_246, 'mediumint(8) unsigned'
      t.column   :ffs_247, 'mediumint(8) unsigned'
      t.column   :ffs_248, 'mediumint(8) unsigned'
      t.column   :ffs_249, 'mediumint(8) unsigned'
      t.column   :ffs_250, 'mediumint(8) unsigned'
      t.datetime :ff_date01
      t.datetime :ff_date02
      t.datetime :ff_date03
      t.datetime :ff_date04
      t.datetime :ff_date05
      t.datetime :ff_date06
      t.datetime :ff_date07
      t.datetime :ff_date08
      t.datetime :ff_date09
      t.datetime :ff_date10
      t.datetime :ff_date11
      t.datetime :ff_date12
      t.datetime :ff_date13
      t.datetime :ff_date14
      t.datetime :ff_date15
      t.datetime :ff_date16
      t.datetime :ff_date17
      t.datetime :ff_date18
      t.datetime :ff_date19
      t.datetime :ff_date20
      t.datetime :ff_date21
      t.datetime :ff_date22
      t.datetime :ff_date23
      t.datetime :ff_date24
      t.datetime :ff_date25
      t.datetime :ff_date26
      t.datetime :ff_date27
      t.datetime :ff_date28
      t.datetime :ff_date29
      t.datetime :ff_date30
      t.integer  :ff_int01, limit: 8
      t.integer  :ff_int02, limit: 8
      t.integer  :ff_int03, limit: 8
      t.integer  :ff_int04, limit: 8
      t.integer  :ff_int05, limit: 8
      t.integer  :ff_int06, limit: 8
      t.integer  :ff_int07, limit: 8
      t.integer  :ff_int08, limit: 8
      t.integer  :ff_int09, limit: 8
      t.integer  :ff_int10, limit: 8
      t.integer  :ff_int11, limit: 8
      t.integer  :ff_int12, limit: 8
      t.integer  :ff_int13, limit: 8
      t.integer  :ff_int14, limit: 8
      t.integer  :ff_int15, limit: 8
      t.integer  :ff_int16, limit: 8
      t.integer  :ff_int17, limit: 8
      t.integer  :ff_int18, limit: 8
      t.integer  :ff_int19, limit: 8
      t.integer  :ff_int20, limit: 8
      t.integer  :ff_int21, limit: 8
      t.integer  :ff_int22, limit: 8
      t.integer  :ff_int23, limit: 8
      t.integer  :ff_int24, limit: 8
      t.integer  :ff_int25, limit: 8
      t.integer  :ff_int26, limit: 8
      t.integer  :ff_int27, limit: 8
      t.integer  :ff_int28, limit: 8
      t.integer  :ff_int29, limit: 8
      t.integer  :ff_int30, limit: 8
      t.boolean  :ff_boolean01
      t.boolean  :ff_boolean02
      t.boolean  :ff_boolean03
      t.boolean  :ff_boolean04
      t.boolean  :ff_boolean05
      t.boolean  :ff_boolean06
      t.boolean  :ff_boolean07
      t.boolean  :ff_boolean08
      t.boolean  :ff_boolean09
      t.boolean  :ff_boolean10
      t.boolean  :ff_boolean11
      t.boolean  :ff_boolean12
      t.boolean  :ff_boolean13
      t.boolean  :ff_boolean14
      t.boolean  :ff_boolean15
      t.boolean  :ff_boolean16
      t.boolean  :ff_boolean17
      t.boolean  :ff_boolean18
      t.boolean  :ff_boolean19
      t.boolean  :ff_boolean20
      t.boolean  :ff_boolean21
      t.boolean  :ff_boolean22
      t.boolean  :ff_boolean23
      t.boolean  :ff_boolean24
      t.boolean  :ff_boolean25
      t.boolean  :ff_boolean26
      t.boolean  :ff_boolean27
      t.boolean  :ff_boolean28
      t.boolean  :ff_boolean29
      t.boolean  :ff_boolean30
    end

    add_index :ticket_field_data, [:account_id, :flexifield_set_id],
          name: 'index_flexifields_on_flexifield_def_id_and_flexifield_set_id'
    add_index :ticket_field_data, [:flexifield_def_id],
          :name => 'index_flexifields_on_flexifield_def_id'
    execute 'ALTER TABLE ticket_field_data DROP PRIMARY KEY, ADD PRIMARY KEY (id,account_id)'
  end

  def down
    drop_table :ticket_field_data
  end

end
