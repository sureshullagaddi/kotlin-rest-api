package com.rest.api.service

import com.rest.api.entity.User
import com.rest.api.repository.UserRepository
import org.springframework.stereotype.Service

@Service
class UserService(private val userRepository : UserRepository ) {
    fun getAllUsers(): List<User> = userRepository.findAll()
    fun getUserById(id: Long): User? = userRepository.findById(id).orElse(null)
    fun createUser(user : User): User = userRepository.save(user)
    fun deleteUser(id: Long) = userRepository.deleteById(id)
}