package com.shopnow.identity.infrastructure.web

import com.shopnow.identity.application.command.RegisterUserCommand
import com.shopnow.identity.application.command.UpdateUserCommand
import com.shopnow.identity.application.dto.UserDTO
import com.shopnow.identity.application.usecase.*
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.tags.Tag
import kotlinx.coroutines.flow.Flow
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import java.net.URI
import java.time.LocalDate
import java.util.*

/**
 * User REST Controller
 *
 * Input adapter that exposes user endpoints via HTTP.
 * Follows hexagonal architecture principles.
 */
@RestController
@RequestMapping("/api/users")
@Tag(name = "Users", description = "Identity & Access Management")
class UserController(
    private val registerUserUseCase: RegisterUserUseCase,
    private val getUserByIdUseCase: GetUserByIdUseCase,
    private val getAllUsersUseCase: GetAllUsersUseCase,
    private val updateUserUseCase: UpdateUserUseCase,
    private val activateUserUseCase: ActivateUserUseCase,
    private val deactivateUserUseCase: DeactivateUserUseCase
) {

    @PostMapping
    @Operation(summary = "Register a new user", description = "Creates a new user account")
    suspend fun registerUser(@RequestBody request: RegisterUserRequest): ResponseEntity<RegisterUserResponse> {
        val command = RegisterUserCommand(
            username = request.username,
            email = request.email,
            password = request.password,
            firstName = request.firstName,
            lastName = request.lastName,
            dateOfBirth = request.dateOfBirth,
            phoneNumber = request.phoneNumber
        )

        val userId = registerUserUseCase.execute(command)

        return ResponseEntity
            .created(URI.create("/api/users/$userId"))
            .body(RegisterUserResponse(userId))
    }

    @GetMapping
    @Operation(summary = "Get all users", description = "Retrieves all users with pagination")
    suspend fun getAllUsers(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): Flow<UserDTO> {
        return getAllUsersUseCase.execute(page, size)
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get user by ID", description = "Retrieves a user by their unique identifier")
    suspend fun getUserById(@PathVariable id: UUID): ResponseEntity<UserDTO> {
        val user = getUserByIdUseCase.execute(id)
        return ResponseEntity.ok(user)
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update user profile", description = "Updates user profile information")
    suspend fun updateUser(
        @PathVariable id: UUID,
        @RequestBody request: UpdateUserRequest
    ): ResponseEntity<Void> {
        val command = UpdateUserCommand(
            firstName = request.firstName,
            lastName = request.lastName,
            dateOfBirth = request.dateOfBirth,
            phoneNumber = request.phoneNumber
        )

        updateUserUseCase.execute(id, command)
        return ResponseEntity.noContent().build()
    }

    @PostMapping("/{id}/activate")
    @Operation(summary = "Activate user", description = "Activates a user account")
    suspend fun activateUser(@PathVariable id: UUID): ResponseEntity<Void> {
        activateUserUseCase.execute(id)
        return ResponseEntity.noContent().build()
    }

    @PostMapping("/{id}/deactivate")
    @Operation(summary = "Deactivate user", description = "Deactivates a user account")
    suspend fun deactivateUser(@PathVariable id: UUID): ResponseEntity<Void> {
        deactivateUserUseCase.execute(id)
        return ResponseEntity.noContent().build()
    }
}

// Request/Response DTOs
data class RegisterUserRequest(
    val username: String,
    val email: String,
    val password: String,
    val firstName: String? = null,
    val lastName: String? = null,
    val dateOfBirth: LocalDate? = null,
    val phoneNumber: String? = null
)

data class RegisterUserResponse(
    val id: UUID
)

data class UpdateUserRequest(
    val firstName: String? = null,
    val lastName: String? = null,
    val dateOfBirth: LocalDate? = null,
    val phoneNumber: String? = null
)
